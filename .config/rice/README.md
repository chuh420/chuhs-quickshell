# still / material

Quickshell runs the material desktop from `~/.config/quickshell/material`. Hyprland calls `~/.config/rice/start`, which starts `rice-quickshell.service` and `rice-session.target`. panel shortcuts and icon refreshes target Quickshell.

restart with `systemctl --user restart rice-quickshell.service`; inspect logs with `journalctl --user -u rice-quickshell.service`. after editing QML, restart the service if IPC reports “not ready to accept queries yet”. the session target supervises hyprpaper, hypridle and clipboard history. restarting the shell keeps these helpers running. Quickshell itself owns notifications, the volume and brightness OSD, battery data through UPower, and the wallpaper layer.

application and icon changes request a shell refresh through `rice-shell-assets.path`. the refresh helper waits in 15-second intervals until pacman releases its database lock, restarts Quickshell, then waits another 15 seconds before accepting another refresh. the refresh service has no startup timeout while waiting for package operations. this spacing keeps package updates from exhausting the shell's restart limit. if the shell reports `start-limit-hit`, run `systemctl --user reset-failed rice-quickshell.service rice-shell-assets.service`, then `systemctl --user start rice-quickshell.service`.

## controls

| action | shortcut |
| --- | --- |
| application search | `Super + D` |
| control center | `Super + Space` |
| wallpaper gallery | `Super + B` |
| notifications | `Super + N` |
| clipboard history | `Super + C` |
| do not disturb | right-click the bell |
| lock | `Super + Ctrl + L` |
| screenshot selection / Satty | `Print` |
| screenshot to file and clipboard | `Ctrl + Print` |

click the clock for the calendar; Left and Right change the month, Up and Down change the year, `T` returns to today. click a workspace to switch desktops. the bar shows CPU, RAM, keyboard layout, connectivity, audio and battery. click the keyboard indicator to change layouts; `Alt + Shift` also works. scroll over audio to change volume; right-click to mute.

the control center opens Wi-Fi and Bluetooth settings. right-click its Bluetooth tile to toggle power. right-click its volume value for the sound panel. the sound panel selects output and microphone devices and opens pavucontrol through “mixer”. keep awake holds a Wayland idle inhibitor on the bar while enabled and resets after a shell restart. manual locking remains available.

the power button in the control center opens the session menu. pick lock, sleep, restart or power off with the mouse, arrows and Enter, or keys 1 to 4. restart and power off wait 1.8 seconds; press Escape or the same tile again to cancel.

## applications and tray

the application catalog supports Unicode search across names and descriptions. use arrows and Enter to launch, `Ctrl + H` to hide the selected application, and `Ctrl + Shift + H` to show hidden applications. hidden IDs live in `~/.local/state/quickshell/material/hidden-applications.json`. terminal entries launch through kitty with their desktop arguments and working directory.

right-click a tray icon for open, application menu and quit. menu-only icons open their menu on a left click. nested menus retain their parent menus. use arrows, Enter and Left to navigate; Escape closes the panel. quit resolves the tray process identity before sending a termination signal.

## notifications and OSD

Quickshell registers as the notification server. popups appear under the bar on the right; hover pauses the timer, a click runs the default action, a swipe or right-click dismisses the notification. critical notifications stay until you dismiss them. `Super + N` opens the history with clear all and do not disturb. do not disturb holds every popup except critical ones and resets after a shell restart.

volume, microphone and brightness keys go through `chuhshell` to the shell, which changes the value and shows the OSD at the bottom of the screen. the OSD also shows keyboard layout changes, copied text or images, and window layout switches from `Super + Shift + L`.

`Super + Escape` pauses every Hyprland shortcut except itself. while paused, the bar shows a yellow keyboard icon and the OSD says so; press `Super + Escape` again to resume. the control, sound and battery panels hide the OSD for their own values.

## clipboard

`Super + C` opens clipboard history from cliphist. type to filter text entries, use arrows and Enter to copy, and Delete to remove an entry. image entries show a preview cached in `~/.cache/quickshell/material/clipboard`. clear all wipes the whole history.

## wallpapers

add PNG, JPEG, WebP, AVIF or BMP images to `~/Pictures/Wallpapers`. reopen the gallery or select refresh. click a preview to apply it, or use arrows and Enter. the gallery creates previews for the visible rows and caches them in `~/.cache/quickshell/material/wallpapers`; closing it cancels pending conversions.

the shared wallpaper helper saves the choice in `~/.local/state/rice/wallpaper.json` and updates hyprpaper and hyprlock. login restores the saved image. Quickshell watches that file and draws the wallpaper on its own layer above hyprpaper; a new image opens as a circle from the clicked preview, or from the screen center when another tool changes it. hyprpaper stays underneath as a fallback when the shell is down.

## panel commands

`quickshell ipc -c material call shell NAME` accepts `launcher`, `menu`, `calendar`, `wallpapers`, `wifi`, `bluetooth`, `audio`, `battery`, `notifications`, `clipboard`, `power`, `dnd`, `volumeUp`, `volumeDown`, `volumeMute`, `micMute`, `brightnessUp`, `brightnessDown` and `close`. `~/.local/bin/chuhshell` wraps panel and desktop actions. use `chuhshell audio-panel` for the sound panel and `chuhshell audio` for pavucontrol. when Quickshell does not answer, `chuhshell` falls back to swaync, swayosd, rofi or plain `wpctl` and `brightnessctl`.

## retained Pleamar

Pleamar and its configuration remain installed. `systemctl --user start rice-pleamar.service` replaces Quickshell for a manual session; `systemctl --user start rice-quickshell.service` returns to Quickshell. the services conflict. Pleamar pulls in swaync and swayosd for its session; starting Quickshell stops both. shortcuts, application refreshes and the next login use Quickshell; while testing Pleamar, use `pleamar-shell NAME` for its panels. see [Pleamar runtime](pleamar.md).
