import json
import pathlib
import subprocess
import re

def run(args):
    try:
        return subprocess.check_output(args, stderr=subprocess.DEVNULL, timeout=2).decode().strip()
    except Exception:
        return ''

batteries = list(pathlib.Path('/sys/class/power_supply').glob('BAT*'))
data = dict(present=bool(batteries), battery=0, charging=False, network='Offline', connected=False, brightness=50)
if batteries:
    data['battery'] = int((batteries[0] / 'capacity').read_text())
    battery = batteries[0]
    def number(name):
        try:
            return float((battery / name).read_text())
        except (OSError, ValueError):
            return 0
    state = (battery / 'status').read_text().strip()
    data['charging'] = state != 'Discharging'
    data['batteryStatus'] = state
    energy = number('energy_now') or number('charge_now') * number('voltage_now') / 1000000
    full = number('energy_full') or number('charge_full') * number('voltage_now') / 1000000
    design = number('energy_full_design') or number('charge_full_design') * number('voltage_now') / 1000000
    power = number('power_now') or number('current_now') * number('voltage_now') / 1000000
    data['batteryPower'] = round(power / 1000000, 1)
    data['batteryHealth'] = round(full / design * 100) if design else 0
    hours = ((full - energy) if state == 'Charging' else energy) / power if power else 0
    minutes = max(0, round(hours * 60))
    data['batteryTime'] = 'Fully charged' if state == 'Full' else f'{minutes // 60}h {minutes % 60:02d}m' + (' until full' if state == 'Charging' else ' left') if power else 'Calculating…' 
text = re.sub(r'\x1b\[[0-9;]*m', '', run(['iwctl', 'station', 'wlan0', 'show']))
match = re.search(r'Connected network\s+(.+)', text)
if match:
    data['network'] = match[1].strip()
    data['connected'] = True
else:
    route = run(['ip', '-j', 'route', 'show', 'default'])
    try:
        routes = json.loads(route)
        if routes:
            data.update(network=routes[0].get('dev', 'Network'), connected=True)
    except Exception:
        pass
value = run(['brightnessctl', '-m']).split(',')
if len(value) > 3:
    data['brightness'] = int(value[3].strip('%'))
print(json.dumps(data))
