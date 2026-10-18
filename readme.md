[english](readme.md) | [русский](readme.ru.md)

# chuh's quickshell

a Quickshell panel and menus for Hyprland in gruvbox material colors. the configuration includes a control center, application search, calendar, Wi-Fi and Bluetooth settings, output and microphone controls, battery details, a wallpaper gallery and nested tray menus. the bar shows workspaces, time, resources and keyboard layout. QML provides panel, button and workspace animations.

`.config` and `.local` mirror paths relative to the home directory. back up existing files before copying their contents. scripts contain `/home/chuh` paths; replace them for another account. Hyprland configuration and the wider system snapshot live in [dotfiles](https://github.com/chuh420/dotfiles/tree/main/hyprland%20setup).

## setup

required tools include Quickshell 0.3.2, Qt 6, Python, python-dbus, python-gobject, ImageMagick, PipeWire, WirePlumber, BlueZ, iwd, hyprpaper, hypridle, hyprlock, swaync, swayosd, rofi, wl-clipboard, cliphist, grim, slurp, satty, kitty and pavucontrol. the original system uses systemd-resolved for DNS. Pleamar is optional.

after copying the user services, run:

```sh
systemctl --user daemon-reload
systemctl --user enable --now rice-shell-assets.path
~/.config/rice/start
```

configure Hyprland startup and key bindings using the dotfiles snapshot. its `rice.lua` disables compositor animations for `material-bar` and `material-overlay`, which use QML animations. the bar reserves 42 px.

`rice-quickshell.service` runs the shell. `rice-session.target` supervises wallpaper, idle, notification, OSD and clipboard helpers. shortcuts and application/icon refreshes target Quickshell. restart after configuration changes with `systemctl --user restart rice-quickshell.service`; logs are available through `journalctl --user -u rice-quickshell.service`. restart the service if a QML reload leaves IPC reporting “not ready to accept queries yet”.

## controls and state

use `Super + D` for applications, `Super + Space` for the control center, `Super + B` for wallpapers, `Super + N` for notifications and `Super + C` for clipboard history. Escape closes a panel. click the clock for the calendar; scroll over audio to change volume or right-click it to mute. keep awake holds a Wayland idle inhibitor until disabled or the shell restarts.

application search handles Unicode names and metadata. `Ctrl + H` hides the selected entry; `Ctrl + Shift + H` shows hidden entries. terminal applications launch through kitty with their desktop arguments and working directory. hidden IDs are generated under `~/.local/state/quickshell/material` and are excluded from this repository.

add wallpaper images to `~/Pictures/Wallpapers`. the gallery creates previews for visible rows, cancels obsolete conversions and caches previews under `~/.cache/quickshell/material`. applying an image updates hyprpaper and hyprlock. wallpaper selection, caches and clipboard history stay local.

[the desktop guide](.config/rice/README.md) covers panel commands and helper behavior. helper tests run with `python -m unittest discover -s tests -v`. physical reconnection and pairing, audio device changes, multiple outputs and a full logout/login still need hardware checks.

## retained Pleamar

the [Pleamar configuration](.config/pleamar/shells/material/readme.md), runtime patches and performance tools remain available. `systemctl --user start rice-pleamar.service` replaces Quickshell for a manual session; `systemctl --user start rice-quickshell.service` returns to Quickshell. the services conflict. shortcuts, asset refreshes and the next login target Quickshell. use `pleamar-shell NAME` to control Pleamar panels.

historical Pleamar measurements live in [the audit](docs/audit-2026-10-16.md) and [renderer study](docs/optimization-2026-10-16.md).
