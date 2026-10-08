import json
import sys
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
service = 'net.connman.iwd'
agent_path = '/rice/wifi_agent'
pending = None
busy = False
message = ''
bluetooth_pending = None

def emit(data):
    print(json.dumps(data), flush=True)

def iface(path, name):
    return dbus.Interface(bus.get_object(service, path), 'net.connman.iwd.' + name)

def objects():
    return dbus.Interface(bus.get_object(service, '/'), 'org.freedesktop.DBus.ObjectManager').GetManagedObjects()

def station():
    for path, interfaces in objects().items():
        if 'net.connman.iwd.Device' in interfaces:
            return str(path), interfaces
    raise RuntimeError('No Wi-Fi adapter found')

def refresh():
    try:
        managed = objects()
        path, interfaces = station()
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
        emit(dict(kind='state', powered=bool(dev.get('Powered')), state=str(sta.get('State', 'off')), scanning=bool(sta.get('Scanning', False)), networks=networks, busy=busy, message=message, device=str(dev['Name'])))
    except Exception as error:
        emit(dict(kind='state', powered=False, state='unavailable', scanning=False, networks=[], busy=busy, message=str(error), device=''))
    return True

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
        pending = (reply, error)
        name = dbus.Interface(bus.get_object(service, network), 'org.freedesktop.DBus.Properties').Get('net.connman.iwd.Network', 'Name')
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
        bluetooth_pending = (reply, error, kind)
        props = dbus.Interface(bus.get_object('org.bluez', device), 'org.freedesktop.DBus.Properties')
        name = str(props.Get('org.bluez.Device1', 'Alias'))
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

bluetooth_agent = BluetoothAgent(bus, '/rice/bluetooth_agent')
try:
    manager = dbus.Interface(bus.get_object('org.bluez', '/org/bluez'), 'org.bluez.AgentManager1')
    manager.RegisterAgent('/rice/bluetooth_agent', 'KeyboardDisplay')
    manager.RequestDefaultAgent('/rice/bluetooth_agent')
except dbus.DBusException:
    pass

agent = Agent(bus, agent_path)
try:
    iface('/net/connman/iwd', 'AgentManager').RegisterAgent(agent_path)
except Exception as error:
    message = str(error)

def command(source, condition):
    global pending, busy, message, bluetooth_pending
    line = sys.stdin.readline()
    if not line:
        loop.quit()
        return False
    try:
        data = json.loads(line)
        action = data['action']
        message = ''
        if action == 'bluetooth-reply':
            if bluetooth_pending:
                reply, error, mode = bluetooth_pending
                bluetooth_pending = None
                if error and not data.get('accepted'):
                    error(dbus.exceptions.DBusException('Rejected', name='org.bluez.Error.Rejected'))
                elif reply:
                    if mode == 'pin':
                        reply(data.get('value', ''))
                    elif mode == 'passkey':
                        reply(dbus.UInt32(int(data.get('value', '0'))))
                    else:
                        reply()
            emit(dict(kind='bluetooth-prompt', name='', mode='', value=''))
            return True
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
        fail(error)
    return True

loop = GLib.MainLoop()
GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, command)
GLib.timeout_add_seconds(3, refresh)
refresh()
loop.run()
