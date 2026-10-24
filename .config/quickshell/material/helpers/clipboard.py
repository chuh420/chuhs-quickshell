import json
from pathlib import Path
import re
import subprocess
import sys

cache = Path.home() / '.cache/quickshell/material/clipboard'
binary = re.compile(r'^\[\[ binary data (.+?) (\w+) (\d+)x(\d+) \]\]$')


def entries():
    output = subprocess.run(['cliphist', 'list'], capture_output=True, timeout=10).stdout.decode('utf-8', 'replace')
    result = []
    for line in output.splitlines()[:400]:
        identifier, _, preview = line.partition('\t')
        if not identifier.isdigit():
            continue
        match = binary.match(preview)
        if match:
            result.append(dict(id=identifier, kind='image', text='', size=match[1], format=match[2].lower(), width=int(match[3]), height=int(match[4])))
        else:
            result.append(dict(id=identifier, kind='text', text=preview))
    return result


def decode(identifier):
    return subprocess.run(['cliphist', 'decode', identifier], capture_output=True, check=True, timeout=10).stdout


def thumbnail(identifier, extension):
    if not identifier.isdigit() or not extension.isalnum():
        raise ValueError('Invalid clipboard entry')
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / (identifier + '.' + extension)
    if not target.is_file():
        temporary = target.with_suffix('.tmp')
        temporary.write_bytes(decode(identifier))
        temporary.replace(target)
    return target


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else 'list'
    if action == 'list':
        print(json.dumps(entries(), ensure_ascii=False))
    elif action == 'copy':
        subprocess.run(['wl-copy'], input=decode(sys.argv[2]), check=True, timeout=10)
    elif action == 'thumb':
        print(thumbnail(sys.argv[2], sys.argv[3]))
    elif action == 'delete':
        subprocess.run(['cliphist', 'delete'], input=(sys.argv[2] + '\t\n').encode(), check=True, timeout=10)
        for path in cache.glob(sys.argv[2] + '.*'):
            path.unlink(missing_ok=True)
    elif action == 'wipe':
        subprocess.run(['cliphist', 'wipe'], check=True, timeout=10)
        for path in cache.glob('*'):
            path.unlink(missing_ok=True)
    else:
        raise ValueError('Unknown action')


try:
    main()
except (OSError, ValueError, IndexError, subprocess.SubprocessError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)
