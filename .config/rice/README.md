# still / material

Quickshell runs the material desktop from `~/.config/quickshell/material`. Hyprland calls `~/.config/rice/start`, which starts `rice-quickshell.service` and `rice-session.target`. panel shortcuts and icon refreshes target Quickshell.

restart with `systemctl --user restart rice-quickshell.service`; inspect logs with `journalctl --user -u rice-quickshell.service`. after editing QML, restart the service if IPC reports “not ready to accept queries yet”. the session target supervises hyprpaper, hypridle, swaync, swayosd and clipboard history. restarting the shell keeps these helpers running.

## controls

| action | shortcut |
| --- | --- |
| application search | `Super + D` |
| control center | `Super + Space` |
| wallpaper gallery | `Super + B` |
| notifications | `Super + N` |
| clipboard history | `Super + C` |
| lock | `Super + Ctrl + L` |
| screenshot selection / Satty | `Print` |
| screenshot to file and clipboard | `Ctrl + Print` |

click the clock for the calendar. click a workspace to switch desktops. the bar shows CPU, RAM, keyboard layout, connectivity, audio and battery. click the keyboard indicator to change layouts; `Alt + Shift` also works. scroll over audio to change volume; right-click to mute.

the control center opens Wi-Fi and Bluetooth settings. right-click its Bluetooth tile to toggle power. right-click its volume value for the sound panel. the sound panel selects output and microphone devices and opens pavucontrol through “mixer”. keep awake holds a Wayland idle inhibitor on the bar while enabled and resets after a shell restart. manual locking remains available.

## applications and tray

the application catalog supports Unicode search across names and descriptions. use arrows and Enter to launch, `Ctrl + H` to hide the selected application, and `Ctrl + Shift + H` to show hidden applications. hidden IDs live in `~/.local/state/quickshell/material/hidden-applications.json`. terminal entries launch through kitty with their desktop arguments and working directory.

right-click a tray icon for open, application menu and quit. menu-only icons open their menu on a left click. nested menus retain their parent menus. use arrows, Enter and Left to navigate; Escape closes the panel. quit resolves the tray process identity before sending a termination signal.

## wallpapers

add PNG, JPEG, WebP, AVIF or BMP images to `~/Pictures/Wallpapers`. reopen the gallery or select refresh. click a preview to apply it, or use arrows and Enter. the gallery creates previews for the visible rows and caches them in `~/.cache/quickshell/material/wallpapers`; closing it cancels pending conversions.

the shared wallpaper helper saves the choice in `~/.local/state/rice/wallpaper.json` and updates hyprpaper and hyprlock. login restores the saved image.

## panel commands

`quickshell ipc -c material call shell NAME` accepts `launcher`, `menu`, `calendar`, `wallpapers`, `wifi`, `bluetooth`, `audio`, `battery` and `close`. `~/.local/bin/chuhshell` wraps panel and desktop actions. use `chuhshell audio-panel` for the sound panel and `chuhshell audio` for pavucontrol.

## retained Pleamar

Pleamar and its configuration remain installed. `systemctl --user start rice-pleamar.service` replaces Quickshell for a manual session; `systemctl --user start rice-quickshell.service` returns to Quickshell. the services conflict. shortcuts, application refreshes and the next login use Quickshell; while testing Pleamar, use `pleamar-shell NAME` for its panels. see [Pleamar runtime](../pleamar/shells/material/readme.md).
