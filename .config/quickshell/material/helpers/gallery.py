import ctypes
import hashlib
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import time


cache = Path.home() / '.cache/quickshell/material/wallpapers'


def preview_paths(item):
    source = Path(item['path'])
    info = source.stat()
    key = hashlib.sha256(('640x360:' + str(source) + ':' + str(info.st_mtime_ns) + ':' + str(info.st_size)).encode()).hexdigest()
    return source, cache / (key + '.png')


def conversion(source, temporary):
    parent = os.getpid()
    def follow_parent():
        signal.signal(signal.SIGTERM, signal.SIG_DFL)
        if ctypes.CDLL(None).prctl(1, signal.SIGTERM) != 0:
            raise OSError('Cannot bind preview converter to its worker')
        if os.getppid() != parent:
            os.kill(os.getpid(), signal.SIGTERM)
    return subprocess.Popen(['magick', '-limit', 'thread', '1', '-limit', 'memory', '256MiB', str(source) + '[0]', '-auto-orient', '-thumbnail', '640x360^', '-gravity', 'center', '-extent', '640x360', str(temporary)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, preexec_fn=follow_parent)


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=.5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def watch():
    cache.mkdir(parents=True, exist_ok=True)
    requested = []
    completed = {}
    buffered = b''
    current = None
    process = None
    temporary = None
    deadline = 0
    target = None

    def key(item):
        return item['path'], item.get('revision', '')

    def emit(item, picture):
        if picture:
            completed[key(item)] = picture
        print(json.dumps(dict(path=item['path'], revision=item.get('revision', ''), picture=picture)), flush=True)

    def interrupted(signum, frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    print(json.dumps(dict(ready=True)), flush=True)
    try:
        while True:
            ready, _, _ = select.select([sys.stdin], [], [], .05 if process else None)
            if ready:
                chunk = os.read(sys.stdin.fileno(), 65536)
                if not chunk:
                    return
                buffered += chunk
                while b'\n' in buffered:
                    line, buffered = buffered.split(b'\n', 1)
                    try:
                        values = json.loads(line)
                        if not isinstance(values, list) or len(values) > 8 or not all(isinstance(item, dict) and isinstance(item.get('path'), str) and isinstance(item.get('revision', ''), str) for item in values):
                            raise ValueError('Invalid preview request')
                        requested = values
                    except (ValueError, UnicodeError) as error:
                        print(json.dumps(dict(error=str(error))), flush=True)
                if current and key(current) not in {key(item) for item in requested}:
                    stop(process)
                    temporary.unlink(missing_ok=True)
                    current, process, temporary = None, None, None
            if process:
                code = process.poll()
                if code is not None or time.monotonic() >= deadline:
                    stop(process)
                    if code == 0 and temporary.is_file():
                        temporary.replace(target)
                        emit(current, str(target))
                    else:
                        emit(current, '')
                    temporary.unlink(missing_ok=True)
                    current, process, temporary = None, None, None
            while requested and process is None:
                item = requested.pop(0)
                if key(item) in completed:
                    emit(item, completed[key(item)])
                    continue
                try:
                    source, target = preview_paths(item)
                    if target.is_file():
                        emit(item, str(target))
                        continue
                    temporary = target.with_name(target.stem + '.' + str(os.getpid()) + '.png')
                    process = conversion(source, temporary)
                    current = item
                    deadline = time.monotonic() + 20
                except (OSError, subprocess.SubprocessError):
                    if temporary:
                        temporary.unlink(missing_ok=True)
                    temporary = None
                    emit(item, '')
    finally:
        stop(process)
        if temporary:
            temporary.unlink(missing_ok=True)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'watch':
        watch()
        return
    cache.mkdir(parents=True, exist_ok=True)
    items = json.loads(sys.stdin.read())
    for item in items:
        temporary = None
        process = None
        try:
            source, target = preview_paths(item)
            if not target.exists():
                temporary = target.with_name(target.stem + '.' + str(os.getpid()) + '.png')
                process = conversion(source, temporary)
                if process.wait(timeout=20) != 0:
                    raise RuntimeError('Preview conversion failed')
                temporary.replace(target)
            item['picture'] = str(target)
        except (OSError, RuntimeError, subprocess.SubprocessError):
            item['picture'] = ''
        finally:
            stop(process)
            if temporary:
                temporary.unlink(missing_ok=True)
    print(json.dumps(items, ensure_ascii=False))


if __name__ == '__main__':
    main()
