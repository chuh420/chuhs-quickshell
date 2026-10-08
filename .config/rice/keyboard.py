import json
import os
from pathlib import Path
import re
import subprocess
import sys


def keyboard():
    devices = json.loads(subprocess.check_output(['hyprctl', 'devices', '-j'], timeout=3))['keyboards']
    return next((device for device in devices if device.get('main')), devices[0] if devices else {})


def describe(device):
    name = device.get('active_keymap', 'Unknown')
    labels = {'English': 'EN', 'Russian': 'RU', 'Kazakh': 'KZ', 'German': 'DE', 'French': 'FR'}
    label = next((short for language, short in labels.items() if language in name), name[:2].upper())
    return {'device': device.get('name', ''), 'name': name, 'label': label}


def notify(name):
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid())))
    state = runtime / 'rice-layout-notification-id'
    try:
        replace_id = int(state.read_text())
    except (OSError, ValueError):
        replace_id = 0
    result = subprocess.check_output(['gdbus', 'call', '--session', '--dest', 'org.freedesktop.Notifications', '--object-path', '/org/freedesktop/Notifications', '--method', 'org.freedesktop.Notifications.Notify', 'Keyboard', str(replace_id), str(Path.home() / '.config/rice/icons/keyboard.svg'), 'Keyboard layout', name, '[]', "{'transient': <true>, 'urgency': <byte 0>}", '1800'], text=True, timeout=3)
    match = re.search(r'uint32 (\d+)', result)
    if match:
        state.write_text(match[1])


try:
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if action == 'status':
        print(json.dumps(describe(keyboard())))
    elif action == 'next':
        device = keyboard().get('name')
        if device:
            subprocess.run(['hyprctl', 'switchxkblayout', device, 'next'], check=True, stdout=subprocess.DEVNULL, timeout=3)
    elif action == 'notify':
        notify(sys.argv[2])
except (OSError, ValueError, subprocess.SubprocessError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)
