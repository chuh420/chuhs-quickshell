import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

home = Path.home()
folder = home / 'Pictures/Wallpapers'
state = home / '.local/state/rice/wallpaper.json'
default = home / '.config/rice/wallpaper.png'
cache = home / '.cache/rice/wallpapers'
extensions = {'.png', '.jpg', '.jpeg', '.webp', '.avif', '.bmp'}
live_folder = folder / 'live wallpapers'
live_extensions = {'.mp4', '.webm', '.mkv', '.mov'}
live_state = home / '.local/state/rice/live.env'
service = 'rice-live-wallpaper.service'

def is_live(path):
    return path.suffix.lower() in live_extensions

def current():
    try:
        selected = Path(json.loads(state.read_text())['path'])
        if selected.is_file():
            return selected
    except (OSError, KeyError, ValueError):
        pass
    return default

def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(text)
    temporary.replace(path)

def image():
    try:
        selected = Path(json.loads(state.read_text())['image'])
        if selected.is_file():
            return selected
    except (OSError, KeyError, ValueError):
        pass
    return current()

def poster(video, identifier):
    target = cache / (identifier + '-poster.png')
    if not target.exists():
        temporary = target.with_name(target.name + '.tmp.png')
        result = subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-y', '-i', str(video), '-frames:v', '1', '-vf', 'scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080', str(temporary)], capture_output=True, text=True, timeout=60)
        if result.returncode or not temporary.is_file():
            raise RuntimeError('Could not read first video frame')
        temporary.replace(target)
    return target

def control(action):
    subprocess.run(['systemctl', '--user', action, service], capture_output=True, timeout=30)

def apply(path, service_control=True):
    selected = path.expanduser().resolve(strict=True)
    live = is_live(selected)
    if not live and selected.suffix.lower() not in extensions:
        raise ValueError('Unsupported image format')
    identifier = hashlib.sha256((str(selected) + str(selected.stat().st_mtime_ns)).encode()).hexdigest()[:20]
    cache.mkdir(parents=True, exist_ok=True)
    link = cache / (identifier + selected.suffix.lower())
    if not link.exists():
        link.symlink_to(selected)
    shown = poster(link, identifier) if live else link
    active = subprocess.run(['pgrep', '-x', 'hyprpaper'], stdout=subprocess.DEVNULL).returncode == 0
    if active:
        result = subprocess.run(['hyprctl', 'hyprpaper', 'wallpaper', ',' + str(shown) + ',cover'], capture_output=True, text=True, timeout=10)
        if result.returncode or 'error' in result.stdout.lower():
            raise RuntimeError(result.stderr.strip() or result.stdout.strip() or 'Could not apply wallpaper')
    atomic_write(home / '.config/hypr/hyprpaper.conf', 'wallpaper {\n    monitor =\n    path = ' + str(shown) + '\n    fit_mode = cover\n}\nsplash = false\nipc = on\n')
    lock = home / '.config/hypr/hyprlock.conf'
    text = lock.read_text()
    text = re.sub(r'(background\s*\{[^}]*?\bpath\s*=)[^\n]*', lambda match: match[1] + ' ' + str(shown), text, count=1)
    atomic_write(lock, text)
    atomic_write(state, json.dumps({'path': str(selected), 'image': str(shown), 'live': live}, ensure_ascii=False) + '\n')
    if live:
        atomic_write(live_state, 'LIVE_VIDEO=' + str(link) + '\n')
        if service_control:
            control('restart')
    else:
        live_state.unlink(missing_ok=True)
        if service_control:
            control('stop')

try:
    action = sys.argv[1] if len(sys.argv) > 1 else 'list'
    if action == 'list':
        def scan(root, allowed):
            return sorted((p for p in root.iterdir() if p.is_file() and not p.name.startswith('.') and p.suffix.lower() in allowed), key=lambda p: p.name.casefold()) if root.is_dir() else []
        files = scan(folder, extensions) + scan(live_folder, live_extensions)
        print(json.dumps({'current': str(current()), 'image': str(image()), 'live': is_live(current()), 'items': [{'path': str(p.resolve()), 'name': p.stem, 'url': p.resolve().as_uri(), 'live': is_live(p), 'revision': str(p.stat().st_mtime_ns) + ':' + str(p.stat().st_size)} for p in files]}, ensure_ascii=False))
    elif action == 'apply':
        apply(Path(sys.argv[2]))
    elif action == 'restore':
        apply(current(), False)
    else:
        raise ValueError('Unknown action')
except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)
