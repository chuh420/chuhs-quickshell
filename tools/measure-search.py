import argparse
import json
from pathlib import Path
import random
import statistics
import subprocess
import time


parser = argparse.ArgumentParser()
parser.add_argument('--runtime', default=str(Path.home() / '.local/bin/pleamar'))
parser.add_argument('--scene', default='material')
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--cycles', type=int, default=10)
args = parser.parse_args()


def say(*commands):
    return subprocess.check_output([args.runtime, '--say', args.scene, *commands], text=True)


helper = Path.home() / '.config/pleamar/shells/material/helpers/desktop.py'
catalog = json.loads(subprocess.check_output(['python', str(helper), 'list'], text=True))
hidden = set(catalog['hidden'])
queries = ['kitty', '']
expected = {query: sum(app['id'] not in hidden and query.casefold() in (' '.join([app['name'], app['generic'], app['comment']])).casefold() for app in catalog['apps']) for query in queries}
if len(set(expected.values())) != len(queries) or not all(expected.values()):
    raise RuntimeError('Choose queries with distinct nonzero result counts for this catalog')
say('emit close')
say('emit launcher')
if 'yes' not in say('wait opened == true 2s'):
    raise RuntimeError('Launcher did not open')
samples = []
jitter = random.Random(9382)
time.sleep(.7)
try:
    for _ in range(args.cycles):
        for query in queries:
            time.sleep(jitter.uniform(.005, .045))
            start = time.perf_counter()
            if 'yes' not in say('text query ' + query, f'wait count == {expected[query]} 2s'):
                raise RuntimeError('Search did not return the expected count')
            samples.append((time.perf_counter() - start) * 1000)
finally:
    say('text query ')
    say('emit close')
sorted_samples = sorted(samples)
result = {'queries': len(samples), 'median_ms': round(statistics.median(samples), 2), 'p95_ms': round(sorted_samples[min(len(samples) - 1, int(len(samples) * .95))], 2), 'maximum_ms': round(max(samples), 2), 'scope': 'one IPC invocation through a completed nonempty result update; alternating distinct counts with seeded phase jitter; not keyboard-to-display latency'}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
