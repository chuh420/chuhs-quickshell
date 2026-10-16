import importlib.util
import json
import os
from pathlib import Path
import unittest
from unittest.mock import Mock, patch


HELPER = Path(__file__).resolve().parents[1] / '.config/pleamar/shells/material/helpers/wifi.py'
spec = importlib.util.spec_from_file_location('connectivity', HELPER)
connectivity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(connectivity)


class ConnectivityTests(unittest.TestCase):
    def setUp(self):
        connectivity.pending = None
        connectivity.bluetooth_pending = None
        connectivity.pairing_paths = set()
        connectivity.input_buffer = b''
        connectivity.message = 'Wi-Fi unchanged'
        self.events = []
        self.patches = [patch.object(connectivity, 'emit', side_effect=self.events.append), patch.object(connectivity, 'refresh'), patch.object(connectivity, 'bluetooth_refresh')]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)

    def test_batched_and_split_utf8_input(self):
        reader, writer = os.pipe()
        with os.fdopen(reader, 'rb', buffering=0) as stream, patch.object(connectivity.sys, 'stdin', stream), patch.object(connectivity, 'command') as command:
            try:
                wire = b'bad json\n' + json.dumps({'action': 'panel', 'name': 'сеть'}, ensure_ascii=False).encode() + b'\n' + b'{"action":"cancel"}\n'
                split = wire.index('с'.encode()) + 1
                os.write(writer, wire[:split])
                self.assertTrue(connectivity.read_commands(None, None))
                command.assert_not_called()
                os.write(writer, wire[split:])
                self.assertTrue(connectivity.read_commands(None, None))
                self.assertEqual([call.args[0]['action'] for call in command.call_args_list], ['panel', 'cancel'])
                self.assertEqual(self.events[0]['kind'], 'command-error')
            finally:
                os.close(writer)
            with patch.object(connectivity, 'loop', create=True) as loop:
                self.assertFalse(connectivity.read_commands(None, None))
                loop.quit.assert_called_once()

    def test_synchronous_bluetooth_failure_does_not_touch_wifi(self):
        reply, error = Mock(), Mock()
        connectivity.bluetooth_pending = (reply, error, 'confirm')
        connectivity.pairing_paths.add('/device')
        with patch.object(connectivity, 'bus', create=True) as bus:
            bus.get_object.side_effect = RuntimeError('No Bluetooth adapter')
            connectivity.command({'action': 'bt-power', 'enabled': True})
        self.assertEqual(connectivity.message, 'Wi-Fi unchanged')
        self.assertEqual([event['kind'] for event in self.events], ['bluetooth-error', 'bluetooth-prompt'])
        error.assert_called_once()
        reply.assert_not_called()
        self.assertIsNone(connectivity.bluetooth_pending)
        self.assertEqual(connectivity.pairing_paths, set())
        connectivity.refresh.assert_not_called()

    def test_disconnected_agent_reply_still_clears_bluetooth_state(self):
        callback = Mock(side_effect=connectivity.dbus.DBusException('Disconnected'))
        connectivity.bluetooth_pending = (Mock(), callback, 'confirm')
        connectivity.pairing_paths.add('/device')
        connectivity.bluetooth_fail(RuntimeError('Pairing failed'))
        self.assertIsNone(connectivity.bluetooth_pending)
        self.assertEqual(connectivity.pairing_paths, set())
        self.assertEqual([event['kind'] for event in self.events], ['bluetooth-error', 'bluetooth-prompt'])
        self.assertEqual(connectivity.message, 'Wi-Fi unchanged')

    def test_wifi_failure_does_not_cancel_bluetooth(self):
        connectivity.pairing_paths.add('/device')
        connectivity.fail(RuntimeError('Wi-Fi failed'))
        self.assertEqual(connectivity.pairing_paths, {'/device'})
        connectivity.bluetooth_refresh.assert_not_called()
        self.assertEqual(self.events[0]['kind'], 'prompt')

    def test_passkey_reply_and_rejection(self):
        for value, accepted in [('000042', True), ('1234567', False), ('', False), ('abc', False), ('１２', False)]:
            with self.subTest(value=value):
                reply, error = Mock(), Mock()
                connectivity.bluetooth_pending = (reply, error, 'passkey')
                connectivity.command({'action': 'bluetooth-reply', 'accepted': True, 'value': value})
                self.assertIsNone(connectivity.bluetooth_pending)
                if accepted:
                    reply.assert_called_once_with(42)
                    error.assert_not_called()
                else:
                    reply.assert_not_called()
                    error.assert_called_once()
        self.assertEqual(connectivity.message, 'Wi-Fi unchanged')

    def test_pin_and_cancel_reply_once(self):
        for accepted, value in [(True, '1234'), (True, ''), (False, '')]:
            reply, error = Mock(), Mock()
            connectivity.bluetooth_pending = (reply, error, 'pin')
            connectivity.command({'action': 'bluetooth-reply', 'accepted': accepted, 'value': value})
            self.assertEqual(reply.call_count + error.call_count, 1)
            self.assertIsNone(connectivity.bluetooth_pending)
            connectivity.command({'action': 'bluetooth-reply', 'accepted': False})
            self.assertEqual(reply.call_count + error.call_count, 1)


if __name__ == '__main__':
    unittest.main()
