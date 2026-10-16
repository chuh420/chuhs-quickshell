import json
import os
from pathlib import Path
import socket
import subprocess

root = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid()))) / 'hypr' / os.environ['HYPRLAND_INSTANCE_SIGNATURE']
connection = socket.socket(socket.AF_UNIX)
connection.connect(str(root / '.socket2.sock'))
def report():
    result = subprocess.run(['python', str(Path.home() / '.config/rice/keyboard.py'), 'status'], capture_output=True, text=True)
    if result.returncode == 0:
        print(result.stdout.strip(), flush=True)
report()
with connection.makefile() as stream:
    for line in stream:
        if line.startswith(('activelayout>>', 'configreloaded>>')):
            report()
