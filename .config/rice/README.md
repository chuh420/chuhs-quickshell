# still / material

Pleamar is the default shell in `~/.config/pleamar/shells/material`. its [README](../pleamar/shells/material/readme.md) covers runtime setup and services. Quickshell remains installed with its configuration in `~/.config/quickshell/material` for manual use.

Hyprland loads `~/.config/hypr/rice.lua`; `~/.config/rice/start` starts `rice-pleamar.service` and `rice-session.target`. systemd supervises the wallpaper, idle, notification, OSD and clipboard helpers and restarts them after they exit. `~/.local/bin/chuhshell` routes panel commands to Pleamar. inspect logs with `journalctl --user -u rice-pleamar.service`.

- `Super + D`: applications; search, arrows, Enter and Escape.
- `Super + Space`: control center. `Super + N`: notifications. `Super + C`: clipboard history.
- `Super + Ctrl + L`: lock. `Print`: select a screenshot region and open Satty. `Ctrl + Print`: capture the screen to a file and clipboard.
- click the clock for the calendar or a workspace number to switch desktops.
- scroll over audio to change volume; right-click to mute. right-click the control center volume value for pavucontrol.
- connectivity tiles open the native Wi-Fi and Bluetooth panels. right-click the Bluetooth tile to toggle power.

Pleamar reloads scene and logic changes automatically. use `hyprctl reload` for Hyprland changes. GTK and Qt applications may need restarting to apply themes.

## Wallpapers

Super + B opens the Pleamar wallpaper gallery. The control center also has a wallpaper button. Click a preview to apply it; use arrow keys and Enter for keyboard selection. Escape closes the gallery.

Images are read from `~/Pictures/Wallpapers`. Reopen the gallery or click Refresh after adding images. PNG, JPEG, WebP, AVIF and BMP are supported.

The choice is saved in `~/.local/state/rice/wallpaper.json` and restored on login. Hyprlock uses the same selected image. Image paths are passed as separate process arguments, and cached symlinks keep hyprpaper configuration safe for filenames containing spaces or commas.

## Keyboard layout

The bar shows EN/RU for the main keyboard. Click the indicator to switch layouts, or use the existing Alt + Shift shortcut. Changes are handled through Hyprland events and show a short system notification. Consecutive layout notifications replace one another and are marked transient.

## Resource usage

The bar shows total CPU usage and used RAM in GiB, updated every two seconds by `resources.py`. RAM usage excludes available reclaimable cache.

## Background updates

Wi-Fi updates follow iwd D-Bus signals with a 60-second fallback refresh; the open Wi-Fi panel refreshes every 10 seconds. Unchanged states are suppressed. The persistent `status.py watch` helper reads brightness and wired routes every five seconds, battery data every 30 seconds, and battery data every five seconds while its panel is open. Opening a panel requests an immediate status refresh. Running `status.py` without arguments still prints one snapshot. closed panels do not request detailed battery updates.

## Keep awake

The control center has a Keep awake toggle. While enabled, a Wayland idle inhibitor attached to a transparent helper surface prevents automatic locking and screen sleep, including while the control center is closed. Manual lock and suspend remain available. the toggle resets when Pleamar restarts or reloads.
