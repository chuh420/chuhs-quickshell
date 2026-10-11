import json
import os
from pathlib import Path
import select
import sys
import time


def number(path):
    try:
        return float(path.read_text())
    except (OSError, ValueError):
        return 0


def battery_status():
    batteries = sorted(Path('/sys/class/power_supply').glob('BAT*'))
    data = dict(present=bool(batteries), battery=0, charging=False)
    if not batteries:
        return data
    battery = batteries[0]
    try:
        state = (battery / 'status').read_text().strip()
    except OSError:
        state = 'Unknown'
    energy = number(battery / 'energy_now') or number(battery / 'charge_now') * number(battery / 'voltage_now') / 1000000
    full = number(battery / 'energy_full') or number(battery / 'charge_full') * number(battery / 'voltage_now') / 1000000
    design = number(battery / 'energy_full_design') or number(battery / 'charge_full_design') * number(battery / 'voltage_now') / 1000000
    power = number(battery / 'power_now') or number(battery / 'current_now') * number(battery / 'voltage_now') / 1000000
    minutes = max(0, round(((full - energy) if state == 'Charging' else energy) / power * 60)) if power else 0
    remaining = 'Fully charged' if state == 'Full' else f'{minutes // 60}h {minutes % 60:02d}m' + (' until full' if state == 'Charging' else ' left') if power else 'Calculating…'
    data.update(battery=round(number(battery / 'capacity')), charging=state in ('Charging', 'Full', 'Not charging'), batteryStatus=state, batteryPower=round(power / 1000000, 1), batteryHealth=round(full / design * 100) if design else 0, batteryTime=remaining)
    return data


def brightness():
    devices = sorted(Path('/sys/class/backlight').iterdir())
    if not devices:
        return 50
    device = devices[0]
    maximum = number(device / 'max_brightness')
    return max(0, min(100, round(number(device / 'brightness') / maximum * 100))) if maximum else 50


def wired_network():
    try:
        for line in Path('/proc/net/route').read_text().splitlines()[1:]:
            fields = line.split()
            if len(fields) > 3 and fields[1] == '00000000' and int(fields[3], 16) & 1:
                device = fields[0]
                if not (Path('/sys/class/net') / device / 'wireless').exists():
                    return dict(network=device, connected=True)
    except (OSError, ValueError):
        pass
    return dict(network='Offline', connected=False)


def snapshot(battery):
    return dict(battery, brightness=brightness(), **wired_network())


def watch():
    battery = battery_status()
    next_battery = time.monotonic() + 30
    detailed = False
    previous = None
    buffered = ''
    while True:
        now = time.monotonic()
        if now >= next_battery:
            battery = battery_status()
            next_battery = now + (5 if detailed else 30)
        data = snapshot(battery)
        if data != previous:
            print(json.dumps(data), flush=True)
            previous = data
        ready, _, _ = select.select([sys.stdin], [], [], 5)
        if ready:
            chunk = os.read(sys.stdin.fileno(), 4096)
            if not chunk:
                return
            buffered += chunk.decode()
            while '\n' in buffered:
                line, buffered = buffered.split('\n', 1)
                try:
                    request = json.loads(line)
                    detailed = bool(request.get('detailed', detailed))
                    next_battery = 0
                except (ValueError, AttributeError):
                    pass


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'watch':
        watch()
    else:
        print(json.dumps(snapshot(battery_status())))
