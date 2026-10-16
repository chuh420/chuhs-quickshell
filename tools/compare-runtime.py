import argparse
import json
from pathlib import Path
import subprocess
import time


parser = argparse.ArgumentParser()
parser.add_argument('--before', required=True, type=Path)
parser.add_argument('--after', required=True, type=Path)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
fixture = Path(__file__).resolve().parents[1] / 'tests/runtime-visual.plm'


def capture(binary, name):
    with (args.output / (name + '.log')).open('w') as log:
        process = subprocess.Popen([str(binary.resolve()), '--scene', str(fixture), '--no-hud', '--seconds', '5'], stdout=log, stderr=log)
        try:
            time.sleep(2)
            data = json.loads(subprocess.check_output(['hyprctl', 'layers', '-j'], text=True))
            surfaces = [layer for monitor in data.values() for level in monitor['levels'].values() for layer in level if layer.get('pid') == process.pid]
            if len(surfaces) != 1:
                raise RuntimeError('Expected one fixture surface; see ' + str(args.output / (name + '.log')))
            surface = surfaces[0]
            region = f"{surface['x']},{surface['y']} {surface['w']}x{surface['h']}"
            path = args.output / (name + '.png')
            subprocess.run(['grim', '-g', region, str(path)], check=True)
        finally:
            try:
                code = process.wait(timeout=6)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                raise RuntimeError('Fixture runtime did not stop')
            if code != 0:
                raise RuntimeError('Fixture runtime failed; see ' + str(args.output / (name + '.log')))
    return path


before = capture(args.before, 'before')
after = capture(args.after, 'after')

def size(path):
    return tuple(map(int, subprocess.check_output(['magick', 'identify', '-format', '%w %h', str(path)], text=True).split()))

if size(before) != size(after):
    raise RuntimeError('Fixture sizes differ')
comparison = subprocess.run(['magick', 'compare', '-metric', 'AE', str(before), str(after), 'null:'], capture_output=True, text=True)
if comparison.returncode not in (0, 1):
    raise RuntimeError(comparison.stderr)
changed = int(float(comparison.stderr.split()[0]))
width, height = size(before)
result = {'pixels': width * height, 'changed_pixels': changed}
(args.output / 'comparison.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
if changed:
    raise SystemExit(1)
