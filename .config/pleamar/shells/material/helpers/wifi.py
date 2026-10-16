import json
import os
import sys
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

service = 'net.connman.iwd'
agent_path = '/pleamar/wifi_agent'
pending = None
busy = False
message = ''
bluetooth_pending = None
last_state = None
refresh_source = None
panel_source = None

def emit(data):
    print(json.dumps(data), flush=True)

def iface(path, name):
    return dbus.Interface(bus.get_object(service, path), 'net.connman.iwd.' + name)

def objects():
    return dbus.Interface(bus.get_object(service, '/'), 'org.freedesktop.DBus.ObjectManager').GetManagedObjects()

def station(managed=None):
    for path, interfaces in (objects() if managed is None else managed).items():
        if 'net.connman.iwd.Device' in interfaces:
            return str(path), interfaces
    raise RuntimeError('No Wi-Fi adapter found')

def refresh():
    global last_state
    try:
        managed = objects()
        path, interfaces = station(managed)
        dev = interfaces['net.connman.iwd.Device']
        sta = interfaces.get('net.connman.iwd.Station', {})
        networks = []
        if dev.get('Powered') and sta:
            for network, signal in iface(path, 'Station').GetOrderedNetworks():
                props = managed.get(network, {}).get('net.connman.iwd.Network', {})
                networks.append(dict(path=str(network), name=str(props.get('Name', 'Network')), available=True, strength=max(0, min(100, (int(signal) / 100 + 100) * 2)), security=str(props.get('Type', '')), connected=bool(props.get('Connected', False)), saved='KnownNetwork' in props, known=str(props.get('KnownNetwork', ''))))
        seen = {item['known'] for item in networks}
        for known, entry in managed.items():
            props = entry.get('net.connman.iwd.KnownNetwork')
            if props and str(known) not in seen:
                networks.append(dict(path='', name=str(props['Name']), strength=0, security=str(props['Type']), connected=False, saved=True, known=str(known), available=False))
        connected_path = sta.get('ConnectedNetwork')
        connected_props = managed.get(connected_path, {}).get('net.connman.iwd.Network', {})
        connected = bool(dev.get('Powered')) and str(sta.get('State', '')) == 'connected'
        network = str(connected_props.get('Name', next((item['name'] for item in networks if item['connected']), 'Wi-Fi'))) if connected else 'Offline'
        state = dict(kind='state', powered=bool(dev.get('Powered')), state=str(sta.get('State', 'off')), scanning=bool(sta.get('Scanning', False)), networks=networks, busy=busy, message=message, device=str(dev['Name']), connected=connected, network=network)
    except Exception as error:
        state = dict(kind='state', powered=False, state='unavailable', scanning=False, networks=[], busy=busy, message=str(error), device='', connected=False, network='Offline')
    if state != last_state:
        emit(state)
        last_state = state
    return True

def flush_refresh():
    global refresh_source
    refresh_source = None
    refresh()
    return False

def queue_refresh(*args):
    global refresh_source
    if refresh_source is None:
        refresh_source = GLib.timeout_add(150, flush_refresh)

def set_panel_visible(visible):
    global panel_source
    if visible and panel_source is None:
        panel_source = GLib.timeout_add_seconds(10, refresh)
        queue_refresh()
    elif not visible and panel_source is not None:
        GLib.source_remove(panel_source)
        panel_source = None

def finish(*args):
    global busy, message
    busy = False
    message = ''
    refresh()

def fail(error):
    global busy, message
    busy = False
    message = 'Connection failed. Check the password and try again.' if 'Failed' in str(error) else str(error).split(':')[-1].strip()
    emit(dict(kind='prompt', name=''))
    refresh()

class Agent(dbus.service.Object):
    @dbus.service.method('net.connman.iwd.Agent', in_signature='o', out_signature='s', async_callbacks=('reply', 'error'))
    def RequestPassphrase(self, network, reply, error):
        global pending
        name = dbus.Interface(bus.get_object(service, network), 'org.freedesktop.DBus.Properties').Get('net.connman.iwd.Network', 'Name')
        pending = (reply, error)
        emit(dict(kind='prompt', name=str(name)))

    @dbus.service.method('net.connman.iwd.Agent', in_signature='s', out_signature='')
    def Cancel(self, reason):
        global pending
        pending = None
        emit(dict(kind='prompt', name=''))

    @dbus.service.method('net.connman.iwd.Agent', in_signature='', out_signature='')
    def Release(self):
        pass

class BluetoothAgent(dbus.service.Object):
    def ask(self, kind, device, value, reply, error):
        global bluetooth_pending
        props = dbus.Interface(bus.get_object('org.bluez', device), 'org.freedesktop.DBus.Properties')
        name = str(props.Get('org.bluez.Device1', 'Alias'))
        bluetooth_pending = (reply, error, kind)
        emit(dict(kind='bluetooth-prompt', mode=kind, name=name, value=str(value)))

    @dbus.service.method('org.bluez.Agent1', in_signature='ou', out_signature='', async_callbacks=('reply', 'error'))
    def RequestConfirmation(self, device, passkey, reply, error):
        self.ask('confirm', device, f'{int(passkey):06d}', reply, error)

    @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='s', async_callbacks=('reply', 'error'))
    def RequestPinCode(self, device, reply, error):
        self.ask('pin', device, '', reply, error)

    @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='u', async_callbacks=('reply', 'error'))
    def RequestPasskey(self, device, reply, error):
        self.ask('passkey', device, '', reply, error)

    @dbus.service.method('org.bluez.Agent1', in_signature='o', out_signature='', async_callbacks=('reply', 'error'))
    def RequestAuthorization(self, device, reply, error):
        self.ask('authorize', device, '', reply, error)

    @dbus.service.method('org.bluez.Agent1', in_signature='os', out_signature='', async_callbacks=('reply', 'error'))
    def AuthorizeService(self, device, uuid, reply, error):
        self.ask('authorize', device, '', reply, error)

    @dbus.service.method('org.bluez.Agent1', in_signature='os', out_signature='')
    def DisplayPinCode(self, device, pin):
        self.ask('display', device, pin, None, None)

    @dbus.service.method('org.bluez.Agent1', in_signature='ouq', out_signature='')
    def DisplayPasskey(self, device, passkey, entered):
        self.ask('display', device, f'{int(passkey):06d}', None, None)

    @dbus.service.method('org.bluez.Agent1', in_signature='', out_signature='')
    def Cancel(self):
        global bluetooth_pending
        bluetooth_pending = None
        emit(dict(kind='bluetooth-prompt', name='', mode='', value=''))

    @dbus.service.method('org.bluez.Agent1', in_signature='', out_signature='')
    def Release(self):
        self.Cancel()

def command(data):
    global pending, busy, message
    action = data['action']
    is_bluetooth = action.startswith('bt-') or action == 'bluetooth-reply'
    try:
        if action == 'panel':
            set_panel_visible(bool(data.get('visible')))
            return True
        if action == 'bluetooth-reply':
            answer_bluetooth(data)
            return True
        if not is_bluetooth:
            message = ''
        if action == 'password':
            if pending:
                reply, error = pending
                pending = None
                reply(data['password'])
                emit(dict(kind='prompt', name=''))
            return True
        if action == 'cancel':
            if pending:
                reply, error = pending
                pending = None
                error(dbus.exceptions.DBusException('Cancelled', name='net.connman.iwd.Agent.Error.Canceled'))
                emit(dict(kind='prompt', name=''))
            return True
        if action.startswith('bt-'):
            managed = dbus.Interface(bus.get_object('org.bluez', '/'), 'org.freedesktop.DBus.ObjectManager').GetManagedObjects()
            adapter = next((str(p) for p, values in managed.items() if 'org.bluez.Adapter1' in values), None)
            if not adapter:
                raise RuntimeError('No Bluetooth adapter found')
            if action == 'bt-power':
                dbus.Interface(bus.get_object('org.bluez', adapter), 'org.freedesktop.DBus.Properties').Set('org.bluez.Adapter1', 'Powered', dbus.Boolean(data['enabled']))
            elif action == 'bt-scan':
                control = dbus.Interface(bus.get_object('org.bluez', adapter), 'org.bluez.Adapter1')
                (control.StartDiscovery if data['enabled'] else control.StopDiscovery)(reply_handler=lambda: None, error_handler=bluetooth_fail)
            else:
                device_path = data['path']
                device = dbus.Interface(bus.get_object('org.bluez', device_path), 'org.bluez.Device1')
                def connect_paired():
                    try:
                        pairing_paths.discard(device_path)
                        bluetooth_refresh()
                        dbus.Interface(bus.get_object('org.bluez', device_path), 'org.freedesktop.DBus.Properties').Set('org.bluez.Device1', 'Trusted', dbus.Boolean(True))
                        device.Connect(reply_handler=lambda: None, error_handler=bluetooth_fail, timeout=60)
                        emit(dict(kind='bluetooth-prompt', name='', mode='', value=''))
                    except Exception as error:
                        bluetooth_fail(error)
                if action == 'bt-pair':
                    pairing_paths.add(device_path)
                    bluetooth_refresh()
                    device.Pair(reply_handler=connect_paired, error_handler=bluetooth_fail, timeout=120)
                elif action == 'bt-connect':
                    device.Connect(reply_handler=lambda: None, error_handler=bluetooth_fail, timeout=60)
                elif action == 'bt-disconnect':
                    device.Disconnect(reply_handler=lambda: None, error_handler=bluetooth_fail)
                elif action == 'bt-cancel':
                    pairing_paths.discard(device_path)
                    bluetooth_refresh()
                    device.CancelPairing(reply_handler=lambda: None, error_handler=bluetooth_fail)
                elif action == 'bt-forget':
                    dbus.Interface(bus.get_object('org.bluez', adapter), 'org.bluez.Adapter1').RemoveDevice(device_path)
            return True
        path, interfaces = station()
        if action == 'power':
            dbus.Interface(bus.get_object(service, path), 'org.freedesktop.DBus.Properties').Set('net.connman.iwd.Device', 'Powered', dbus.Boolean(data['enabled']))
        elif action == 'scan':
            iface(path, 'Station').Scan(reply_handler=finish, error_handler=fail)
        elif action == 'connect':
            busy = True
            iface(data['path'], 'Network').Connect(reply_handler=finish, error_handler=fail, timeout=120)
        elif action == 'disconnect':
            iface(path, 'Station').Disconnect(reply_handler=finish, error_handler=fail)
        elif action == 'forget':
            iface(data['path'], 'KnownNetwork').Forget()
        refresh()
    except Exception as error:
        if is_bluetooth:
            bluetooth_fail(error)
        else:
            fail(error)
    return True

def answer_bluetooth(data):
    global bluetooth_pending
    if bluetooth_pending:
        reply, error, mode = bluetooth_pending
        bluetooth_pending = None
        if error and not data.get('accepted'):
            error(dbus.exceptions.DBusException('Rejected', name='org.bluez.Error.Rejected'))
        elif reply:
            if mode == 'passkey':
                value = data.get('value', '')
                if not isinstance(value, str) or not value.isascii() or not value.isdigit() or len(value) > 6:
                    error(dbus.exceptions.DBusException('Invalid passkey', name='org.bluez.Error.Rejected'))
                    raise ValueError('Passkey must contain one to six digits')
                reply(dbus.UInt32(int(value)))
            elif mode == 'pin':
                value = data.get('value', '')
                if not isinstance(value, str) or not 1 <= len(value.encode()) <= 16:
                    error(dbus.exceptions.DBusException('Invalid PIN', name='org.bluez.Error.Rejected'))
                    raise ValueError('PIN must contain 1 to 16 bytes')
                reply(value)
            else:
                reply()
    emit(dict(kind='bluetooth-prompt', name='', mode='', value=''))

def bluetooth_fail(error):
    global bluetooth_pending
    pending_reply = bluetooth_pending
    bluetooth_pending = None
    if pending_reply and pending_reply[1]:
        try:
            pending_reply[1](dbus.exceptions.DBusException('Cancelled', name='org.bluez.Error.Canceled'))
        except dbus.DBusException:
            pass
    pairing_paths.clear()
    bluetooth_refresh()
    emit(dict(kind='bluetooth-error', message=str(error)))
    emit(dict(kind='bluetooth-prompt', name='', mode='', value=''))

def bluetooth_refresh(*args):
    try:
        managed = dbus.Interface(bus.get_object('org.bluez', '/'), 'org.freedesktop.DBus.ObjectManager').GetManagedObjects()
        adapter = next((v['org.bluez.Adapter1'] for v in managed.values() if 'org.bluez.Adapter1' in v), {})
        devices = []
        for path, values in managed.items():
            dev = values.get('org.bluez.Device1')
            if dev:
                devices.append(dict(path=str(path), name=str(dev.get('Alias', dev.get('Address', 'Device'))), paired=bool(dev.get('Paired')), connected=bool(dev.get('Connected')), pairing=str(path) in pairing_paths, battery=int(values.get('org.bluez.Battery1', {}).get('Percentage', -1))))
        devices.sort(key=lambda d: (not d['connected'], d['name'].casefold()))
        emit(dict(kind='bluetooth-state', powered=bool(adapter.get('Powered')), discovering=bool(adapter.get('Discovering')), name=str(adapter.get('Alias', 'No adapter')), devices=devices))
    except Exception as error:
        emit(dict(kind='bluetooth-state', powered=False, discovering=False, name=str(error), devices=[]))
    return True

pairing_paths = set()
input_buffer = b''

def read_commands(source, condition):
    global input_buffer
    chunk = os.read(sys.stdin.fileno(), 65536)
    if not chunk:
        loop.quit()
        return False
    input_buffer += chunk
    while b'\n' in input_buffer:
        line, input_buffer = input_buffer.split(b'\n', 1)
        try:
            data = json.loads(line)
            if not isinstance(data, dict) or not isinstance(data.get('action'), str):
                raise ValueError('Invalid connectivity command')
        except (ValueError, UnicodeError) as error:
            emit(dict(kind='command-error', message=str(error)))
            continue
        command(data)
    return True

def main():
    global bus, loop, message
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    bluetooth_agent = BluetoothAgent(bus, '/pleamar/bluetooth_agent')
    try:
        manager = dbus.Interface(bus.get_object('org.bluez', '/org/bluez'), 'org.bluez.AgentManager1')
        manager.RegisterAgent('/pleamar/bluetooth_agent', 'KeyboardDisplay')
        manager.RequestDefaultAgent('/pleamar/bluetooth_agent')
    except dbus.DBusException:
        pass

    agent = Agent(bus, agent_path)
    try:
        iface('/net/connman/iwd', 'AgentManager').RegisterAgent(agent_path)
    except Exception as error:
        message = str(error)

    bus.add_signal_receiver(bluetooth_refresh, signal_name='PropertiesChanged', dbus_interface='org.freedesktop.DBus.Properties', bus_name='org.bluez')
    bus.add_signal_receiver(bluetooth_refresh, signal_name='InterfacesAdded', dbus_interface='org.freedesktop.DBus.ObjectManager', bus_name='org.bluez')
    bus.add_signal_receiver(bluetooth_refresh, signal_name='InterfacesRemoved', dbus_interface='org.freedesktop.DBus.ObjectManager', bus_name='org.bluez')
    bluetooth_refresh()
    loop = GLib.MainLoop()
    GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, read_commands)
    bus.add_signal_receiver(queue_refresh, signal_name='PropertiesChanged', dbus_interface='org.freedesktop.DBus.Properties', bus_name=service)
    bus.add_signal_receiver(queue_refresh, signal_name='InterfacesAdded', dbus_interface='org.freedesktop.DBus.ObjectManager', bus_name=service)
    bus.add_signal_receiver(queue_refresh, signal_name='InterfacesRemoved', dbus_interface='org.freedesktop.DBus.ObjectManager', bus_name=service)
    bus.add_signal_receiver(queue_refresh, signal_name='NameOwnerChanged', dbus_interface='org.freedesktop.DBus', arg0=service)
    GLib.timeout_add_seconds(60, refresh)
    refresh()
    loop.run()

if __name__ == '__main__':
    main()
