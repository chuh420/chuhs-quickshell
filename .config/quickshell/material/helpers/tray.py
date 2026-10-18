import json
import os
from pathlib import Path
import signal
import subprocess
import sys


def bus(*args):
    return json.loads(subprocess.check_output(["busctl", "--user", "--json=short", *args], text=True, timeout=3))["data"]


def resolve(item_id, title):
    items = bus("get-property", "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems")
    matches = set()
    for item in items:
        service, sep, path = item.partition("/")
        path = "/" + path if sep else "/StatusNotifierItem"
        try:
            current_id = bus("get-property", service, path, "org.kde.StatusNotifierItem", "Id")
            current_title = bus("get-property", service, path, "org.kde.StatusNotifierItem", "Title")
            if current_id != item_id or (current_title or current_id) != title:
                continue
            pid = bus("call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", service)[0]
            process = Path("/proc") / str(pid)
            if pid > 1 and process.stat().st_uid == os.getuid():
                matches.add(pid)
        except (OSError, subprocess.SubprocessError):
            continue
    if len(matches) != 1:
        raise RuntimeError("Could not uniquely identify the tray application")
    return matches.pop()


try:
    if sys.argv[1] == 'flags':
        import dbus
        name, separator, path = sys.argv[2].partition('/')
        path = '/' + path if separator else '/StatusNotifierItem'
        session = dbus.SessionBus()
        properties = dbus.Interface(session.get_object(name, path), 'org.freedesktop.DBus.Properties')
        try:
            only_menu = bool(properties.Get('org.kde.StatusNotifierItem', 'ItemIsMenu'))
        except dbus.DBusException:
            only_menu = False
        print(json.dumps({'only_menu': only_menu}))
        sys.exit(0)
    action, item_id, title = sys.argv[1:4]
    pid = resolve(item_id, title)
    if action == "resolve":
        print(pid)
    elif action == "quit":
        os.kill(pid, signal.SIGTERM)
except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
    print(str(error), file=sys.stderr)
    sys.exit(1)
