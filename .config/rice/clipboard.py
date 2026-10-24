import os
from pathlib import Path
import re
import subprocess
import sys

runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/run/user/" + str(os.getuid())))
state = runtime / "rice-clipboard-notification"
owner = str(os.getppid())
try:
    previous_owner, notification_id = state.read_text().split()
except (OSError, ValueError):
    previous_owner, notification_id = "", "0"
initial = previous_owner != owner
state.write_text(owner + " " + notification_id)
data = sys.stdin.buffer.read()
clipboard_state = os.environ.get("CLIPBOARD_STATE", "data")
if clipboard_state in ("nil", "clear", "sensitive") or not data:
    sys.exit(0)
subprocess.run(["cliphist", "store"], input=data, stdout=subprocess.DEVNULL, timeout=10)
if initial:
    sys.exit(0)
if data[:8] == b"\x89PNG\r\n\x1a\n" or data[:3] == b"\xff\xd8\xff":
    preview = "image copied"
else:
    preview = " ".join(data[:400].decode("utf-8", "replace").split())
    preview = "copied · " + (preview[:36] + "…" if len(preview) > 37 else preview) if preview else "copied"
try:
    if subprocess.run(["/home/chuh/.local/bin/chuhshell", "osd", "clipboard", preview], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3).returncode == 0:
        sys.exit(0)
except (OSError, subprocess.SubprocessError):
    pass
try:
    result = subprocess.check_output([
        "gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
        "--object-path", "/org/freedesktop/Notifications", "--method",
        "org.freedesktop.Notifications.Notify", "Clipboard", notification_id,
        "edit-copy", "Copied to clipboard", "", "[]",
        "{'transient': <true>, 'urgency': <byte 0>}", "1500"
    ], text=True, timeout=3)
    match = re.search(r"uint32 (\d+)", result)
    if match:
        state.write_text(owner + " " + match[1])
except (OSError, subprocess.SubprocessError):
    pass
