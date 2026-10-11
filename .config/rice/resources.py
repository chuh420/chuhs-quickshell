import json
from pathlib import Path
import time


previous = None
while True:
    values = [int(value) for value in Path('/proc/stat').read_text().splitlines()[0].split()[1:9]]
    total = sum(values)
    idle = values[3] + values[4]
    cpu = None
    if previous is not None:
        elapsed = total - previous[0]
        if elapsed > 0:
            cpu = max(0, min(100, round(100 * (1 - (idle - previous[1]) / elapsed))))
    previous = total, idle
    memory = {}
    for line in Path('/proc/meminfo').read_text().splitlines():
        key, value = line.split(':', 1)
        memory[key] = int(value.split()[0])
    used = memory['MemTotal'] - memory['MemAvailable']
    print(json.dumps(dict(cpu=cpu, ramUsed=used / 1048576, ramTotal=memory['MemTotal'] / 1048576)), flush=True)
    time.sleep(2)
