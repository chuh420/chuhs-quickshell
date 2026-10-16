[english](readme.md) | [русский](readme.ru.md)

# chuh's quickshell

a Pleamar panel and menus for hyprland in gruvbox material colors. active shell development lives in [pleamar](https://github.com/chuh420/pleamar). this repository retains the combined desktop configuration, including the Pleamar shell, retained Quickshell qml sources, python helpers, a startup script, wallpapers, browser styles and user services for refreshing the shell.

the panel shows workspaces, a clock, battery status, audio, network, bluetooth, keyboard layout, CPU usage, used RAM and a system tray. it includes application search, a calendar, a control center with a session-only Keep awake toggle and a wallpaper gallery. swaync handles notifications, hyprlock handles screen locking, and swayosd displays volume and brightness indicators.

`.config` and `.local` mirror paths relative to the home directory. back up existing files before copying their contents. start the shell with `~/.config/rice/start`, which imports the session environment, starts `rice-pleamar.service` and `rice-session.target`. systemd supervises the desktop helpers. the service restarts the shell after failures; application and icon changes restart Pleamar through `rice-shell-assets.service`. inspect logs with `journalctl --user -u rice-pleamar.service`.

required tools include Pleamar 0.4.2 with the local text rendering and fill optimization patches, ImageMagick, python, python-dbus, python-gobject, qt, pipewire, wireplumber, bluez, iwd, hyprpaper, hypridle, hyprlock, swaync, swayosd, rofi, wl-clipboard, cliphist, grim, slurp, satty and pavucontrol. the original system uses iwd for networking and systemd-resolved for name resolution. system services and hyprland configuration are stored in the corresponding dotfiles setup.

scripts contain `/home/chuh` paths; replace them when using a different account. add gallery wallpapers to the user's wallpaper directory under pictures. clipboard history and shell state are generated locally and excluded from this repository.

after copying the user services, run `systemctl --user daemon-reload` and `systemctl --user enable --now rice-shell-assets.path`. configure key bindings and hyprland integration separately. helper documentation is stored alongside the helpers.

Wi-Fi uses event-driven updates and system status uses a persistent helper to reduce background work. See the helper documentation for refresh intervals.

## shell services

Pleamar is the session default. its [README](.config/pleamar/shells/material/readme.md) covers the runtime build, adapters and manual switching. build the runtime and idle inhibitor before the first launch.

`chuhshell` shortcuts and asset refreshes always use Pleamar. Quickshell remains installed with its configuration and service for manual use. `systemctl --user start rice-quickshell.service` replaces Pleamar; `systemctl --user start rice-pleamar.service` returns to Pleamar. the services conflict, and a new login starts Pleamar. there is no automatic fallback to Quickshell.

[the audit](docs/audit-2026-10-16.md) and [renderer study](docs/optimization-2026-10-16.md) cover fixes, measurements and validation limits. run `python -m unittest discover -s tests -v` for the helper checks.
