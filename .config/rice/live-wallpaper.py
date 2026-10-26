import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time

video = os.environ['LIVE_VIDEO']
options = ' '.join([
    'no-audio', 'loop-file=inf', 'hwdec=vaapi', 'panscan=1.0', 'profile=fast',
    'vd-lavc-threads=1', 'framedrop=vo', 'interpolation=no', 'cache=no',
    'demuxer-max-bytes=16MiB', 'demuxer-max-back-bytes=0', 'scale=bilinear', 'dither-depth=no',
])
player = subprocess.Popen(['/usr/bin/mpvpaper', '-p', '-l', 'bottom', '-o', options, 'ALL', video])
stopped = False

def hyprctl(*arguments):
    return json.loads(subprocess.run(['hyprctl', *arguments, '-j'], capture_output=True, text=True, timeout=5).stdout)

def covered():
    if subprocess.run(['pgrep', '-x', 'hyprlock'], stdout=subprocess.DEVNULL).returncode == 0:
        return True
    return hyprctl('activeworkspace').get('windows', 0) > 0

def update():
    global stopped
    want = covered()
    if want != stopped and player.poll() is None:
        player.send_signal(signal.SIGSTOP if want else signal.SIGCONT)
        stopped = want

def finish(signum, frame):
    if player.poll() is None:
        if stopped:
            player.send_signal(signal.SIGCONT)
        player.terminate()
        try:
            player.wait(timeout=3)
        except subprocess.TimeoutExpired:
            player.kill()
    sys.exit(0)

signal.signal(signal.SIGTERM, finish)
signal.signal(signal.SIGINT, finish)

path = Path(os.environ['XDG_RUNTIME_DIR']) / 'hypr' / os.environ['HYPRLAND_INSTANCE_SIGNATURE'] / '.socket2.sock'
events = socket.socket(socket.AF_UNIX)
events.settimeout(5)
events.connect(str(path))
update()
buffered = b''
while player.poll() is None:
    try:
        chunk = events.recv(65536)
        if not chunk:
            break
        buffered += chunk
    except socket.timeout:
        update()
        continue
    names = {line.split(b'>>', 1)[0] for line in buffered.split(b'\n') if b'>>' in line}
    buffered = buffered.rsplit(b'\n', 1)[-1]
    if names & {b'openwindow', b'closewindow', b'movewindow', b'movewindowv2', b'workspace', b'workspacev2', b'activewindow', b'fullscreen', b'focusedmon', b'changefloatingmode'}:
        time.sleep(.05)
        update()
sys.exit(player.poll() or 1)
