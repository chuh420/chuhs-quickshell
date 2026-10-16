import argparse
from pathlib import Path
import subprocess
import time


parser = argparse.ArgumentParser()
parser.add_argument('--runtime', default=str(Path.home() / '.local/bin/pleamar'))
parser.add_argument('--scene', default='material')
parser.add_argument('--cycles', type=int, default=12)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()


def say(*commands):
    return subprocess.check_output([args.runtime, '--say', args.scene, *commands], text=True)


say('emit close')
time.sleep(.7)
say('probe')
try:
    for index in range(args.cycles):
        say('emit ' + ('launcher' if index % 2 == 0 else 'menu'))
        time.sleep(.65)
        say('emit close')
        time.sleep(.55)
finally:
    say('emit close')
report = say('probe report')
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(report)
print(report)
