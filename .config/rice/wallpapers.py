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

def apply(path):
    selected = path.expanduser().resolve(strict=True)
    if selected.suffix.lower() not in extensions:
        raise ValueError('Unsupported image format')
    identifier = hashlib.sha256((str(selected) + str(selected.stat().st_mtime_ns)).encode()).hexdigest()[:20]
    cache.mkdir(parents=True, exist_ok=True)
    link = cache / (identifier + selected.suffix.lower())
    if not link.exists():
        link.symlink_to(selected)
    active = subprocess.run(['pgrep', '-x', 'hyprpaper'], stdout=subprocess.DEVNULL).returncode == 0
    if active:
        result = subprocess.run(['hyprctl', 'hyprpaper', 'wallpaper', ',' + str(link) + ',cover'], capture_output=True, text=True, timeout=10)
        if result.returncode or 'error' in result.stdout.lower():
            raise RuntimeError(result.stderr.strip() or result.stdout.strip() or 'Could not apply wallpaper')
    atomic_write(home / '.config/hypr/hyprpaper.conf', 'wallpaper {\n    monitor =\n    path = ' + str(link) + '\n    fit_mode = cover\n}\nsplash = false\nipc = on\n')
    lock = home / '.config/hypr/hyprlock.conf'
    text = lock.read_text()
    text = re.sub(r'(background\s*\{[^}]*?\bpath\s*=)[^\n]*', lambda match: match[1] + ' ' + str(link), text, count=1)
    atomic_write(lock, text)
    atomic_write(state, json.dumps({'path': str(selected)}, ensure_ascii=False) + '\n')

try:
    action = sys.argv[1] if len(sys.argv) > 1 else 'list'
    if action == 'list':
        files = sorted((p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in extensions), key=lambda p: p.name.casefold()) if folder.is_dir() else []
        print(json.dumps({'current': str(current()), 'items': [{'path': str(p.resolve()), 'name': p.stem, 'url': p.resolve().as_uri()} for p in files]}, ensure_ascii=False))
    elif action == 'apply':
        apply(Path(sys.argv[2]))
    elif action == 'restore':
        apply(current())
    else:
        raise ValueError('Unknown action')
except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)
