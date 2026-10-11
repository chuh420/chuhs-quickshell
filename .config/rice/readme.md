[english](readme.md) | [русский](readme.ru.md)

# still / material

a warm gruvbox material palette with graphite, cream, olive and amber accents.

the shell lives in `~/.config/quickshell/material`, with its palette defined by the theme qml component. hyprland customization is in `~/.config/hypr/rice.lua`; default wallpapers are in `~/.config/rice`. startup uses `~/.config/rice/start`, and desktop commands use `~/.local/bin/chuhshell`.

- super + d - open application search; use arrow keys, enter and escape.
- super + space - open the control center.
- super + n - open notifications.
- super + c - open clipboard history.
- super + ctrl + l - lock the screen.
- print - select a screenshot region and open satty.
- ctrl + print - save a full screenshot and copy it to the clipboard.
- click the clock - open the calendar.
- click a workspace number - switch workspaces.
- scroll over the audio icon - adjust volume; right click - toggle mute.
- right click the volume percentage - open pavucontrol.
- right click the bluetooth switch - open bluetoothctl in a terminal.
- click the arrow by the network - open iwctl in a terminal.

quickshell automatically reloads qml changes. apply hyprland changes with `hyprctl reload`. gtk and qt applications may need a restart to pick up theme changes.

local configuration backups are stored in `~/.local/state/rice/backup-*`; `last-backup` points to the latest one. these backups are excluded from the repository. to recover an existing local backup, stop quickshell with `systemctl --user stop rice-quickshell.service`, restore the relevant directories and run `hyprctl reload`.

bluez, pipewire-audio and pipewire-pulse were added because the original system lacked the bluetooth daemon and pipewire audio plugins. bluetooth and the user pipewire-pulse service were enabled.

## wallpapers

super + b opens the wallpaper gallery. the control center also has a wallpaper button. click a preview to apply it or use arrow keys and enter. escape closes the gallery.

images are read from the `~/Pictures/Wallpapers`. reopen the gallery or click refresh after adding images. png, jpeg, webp, avif and bmp are supported.

the selection is saved in `~/.local/state/rice/wallpaper.json` and restored on login. hyprlock uses the same image. image paths are passed as separate process arguments; cached symlinks keep hyprpaper configuration safe for filenames containing spaces or commas.

## keyboard layout

the panel shows en/ru for the main keyboard. click the indicator to switch layouts or use alt + shift. hyprland events update the indicator and produce a short notification. consecutive layout notifications replace one another and are transient.

## Background updates

Wi-Fi updates follow iwd D-Bus signals with a 60-second fallback refresh; the open Wi-Fi panel refreshes every 10 seconds. Unchanged states are suppressed. The persistent `status.py watch` helper reads brightness and wired routes every five seconds, battery data every 30 seconds, and battery data every five seconds while its panel is open. Opening a panel requests an immediate status refresh. Running `status.py` without arguments still prints one snapshot. Closed popup content is unloaded.

## Shell service

`~/.config/rice/start` imports the Wayland/Hyprland environment and starts `rice-quickshell.service`. It runs Quickshell in the foreground and restarts it after failures. Use `systemctl --user restart rice-quickshell.service` to restart and `journalctl --user -u rice-quickshell.service` to inspect logs. Run the startup script after restoring a backup.

## Resource usage

`resources.py` reads `/proc/stat` and `/proc/meminfo` every two seconds. The bar shows total CPU usage and used RAM in GiB, calculated as `MemTotal - MemAvailable`.

## Keep awake

The control center toggle uses a Wayland idle inhibitor on each bar to prevent automatic locking and screen sleep while enabled. Manual lock and suspend remain available. The toggle resets on shell restart or reload.
