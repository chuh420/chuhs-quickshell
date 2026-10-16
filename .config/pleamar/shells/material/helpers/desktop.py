import calendar
import datetime
import json
import os
from pathlib import Path
import sys
from gi.repository import Gio, GLib

state = Path.home() / '.local/state/pleamar/material/hidden-applications.json'

def hidden():
    try:
        data = json.loads(state.read_text())
        if not isinstance(data, list):
            return []
        return [item if item.endswith('.desktop') else item + '.desktop' for item in data if isinstance(item, str)]
    except (OSError, ValueError):
        return []

def applications():
    result = []
    for app in Gio.AppInfo.get_all():
        if not app.should_show():
            continue
        icon = app.get_icon()
        icon_name = icon.get_names()[0] if isinstance(icon, Gio.ThemedIcon) else icon.get_file().get_path() if isinstance(icon, Gio.FileIcon) else ''
        result.append(dict(id=app.get_id(), name=app.get_display_name(), initial=app.get_display_name()[:1], generic=app.get_generic_name() or '', comment=app.get_description() or '', icon=icon_name, terminal=app.get_boolean('Terminal')))
    return sorted(result, key=lambda app: (not any(term in app['id'].lower() for term in ('kitty', 'zen', 'dolphin', 'pavucontrol')), app['name'].casefold()))

def save_hidden(data):
    if not isinstance(data, list) or not all(isinstance(item, str) for item in data):
        raise ValueError('Invalid hidden application IDs')
    state.parent.mkdir(parents=True, exist_ok=True)
    temporary = state.with_suffix('.tmp')
    temporary.write_text(json.dumps(data) + '\n')
    temporary.replace(state)

def watch():
    indexed = []
    request = {}
    buffered = b''
    refresh_source = None
    loop = GLib.MainLoop()
    def respond():
        query = request.get('query', '')
        matches = [app for app, searchable in indexed if query.casefold() in searchable]
        print(json.dumps(dict(apps=matches, hidden=hidden(), query=query, generation=request.get('generation', 0)), ensure_ascii=False), flush=True)
    def reload_catalog():
        nonlocal indexed, refresh_source
        refresh_source = None
        indexed = [(app, (app['name'] + ' ' + app['generic'] + ' ' + app['comment']).casefold()) for app in applications()]
        respond()
        return False
    def changed(monitor):
        nonlocal refresh_source
        if refresh_source is None:
            refresh_source = GLib.timeout_add(100, reload_catalog)
    def receive(source, condition):
        nonlocal buffered, request
        chunk = os.read(sys.stdin.fileno(), 65536)
        if not chunk:
            loop.quit()
            return False
        buffered += chunk
        while b'\n' in buffered:
            line, buffered = buffered.split(b'\n', 1)
            try:
                value = json.loads(line)
                if not isinstance(value, dict) or not isinstance(value.get('query', ''), str):
                    raise ValueError('Invalid application query')
                if 'hidden' in value:
                    save_hidden(value['hidden'])
                request = value
                respond()
            except (OSError, ValueError, TypeError, AttributeError) as error:
                print(json.dumps(dict(error=str(error))), flush=True)
        return True
    monitor = Gio.AppInfoMonitor.get()
    monitor.connect('changed', changed)
    GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, receive)
    reload_catalog()
    loop.run()

def terminal_arguments(app):
    command = app.get_string('Exec') or ''
    _, tokens = GLib.shell_parse_argv(command)
    arguments = []
    files = 0
    for token in tokens:
        if token == '%i':
            icon = app.get_string('Icon')
            if icon:
                arguments.extend(['--icon', icon])
            continue
        if token in ('%F', '%U'):
            files += 1
            continue
        expanded = ''
        position = 0
        removed = False
        while position < len(token):
            character = token[position]
            position += 1
            if character != '%':
                expanded += character
                continue
            if position == len(token):
                raise ValueError('Incomplete desktop field code')
            code = token[position]
            position += 1
            if code == '%':
                expanded += '%'
            elif code == 'c':
                expanded += app.get_name()
            elif code == 'k':
                expanded += app.get_filename() or ''
            elif code in 'fu':
                files += 1
                removed = True
            elif code in 'dDnNvm':
                removed = True
            else:
                raise ValueError('Invalid desktop field code: %' + code)
        if expanded or not removed:
            arguments.append(expanded)
    if files > 1:
        raise ValueError('Multiple desktop file field codes')
    if not arguments or not arguments[0]:
        raise ValueError('Missing desktop executable')
    return arguments

def main():
    action = sys.argv[1]
    if action == 'watch':
        watch()
    elif action == 'list':
        query = sys.argv[2].casefold() if len(sys.argv) > 2 else ''
        matches = [app for app in applications() if query in (app['name'] + ' ' + app['generic'] + ' ' + app['comment']).casefold()]
        print(json.dumps(dict(apps=matches, hidden=hidden()), ensure_ascii=False))
    elif action == 'launch':
        app = Gio.DesktopAppInfo.new(sys.argv[2])
        if app is None:
            raise ValueError('Application no longer exists')
        if app.get_boolean('Terminal'):
            import subprocess
            subprocess.Popen(['kitty', '-e', *terminal_arguments(app)], cwd=app.get_string('Path') or None, start_new_session=True)
        else:
            app.launch([], None)
    elif action == 'hidden':
        save_hidden(json.loads(sys.stdin.read()))
    elif action == 'calendar':
        today = datetime.date.today()
        first = today.replace(day=1)
        start = first - datetime.timedelta(days=first.weekday())
        print(json.dumps(dict(title=today.strftime('%B %Y'), cells=[dict(day=str((start + datetime.timedelta(days=i)).day), current=(start + datetime.timedelta(days=i)) == today, month=(start + datetime.timedelta(days=i)).month == today.month) for i in range(42)])))

if __name__ == '__main__':
    main()
