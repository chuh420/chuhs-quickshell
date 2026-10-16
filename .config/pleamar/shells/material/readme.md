# material shell for pleamar

this shell ports the existing Gruvbox Material desktop to pleamar 0.4.2 (`ecc52f63f8179bc974a084180ddb2fdf49273edf`) with the local text rendering and fill optimization patches. Pleamar is the session default. Quickshell stays installed with its configuration for manual use.

## running

Hyprland starts `~/.config/rice/start`, which imports the session environment and starts `rice-pleamar.service` and `rice-session.target`. `chuhshell` shortcuts and application/icon refreshes use Pleamar. the service restarts Pleamar after failures; it does not restore Quickshell.

use `systemctl --user restart rice-pleamar.service` to restart the shell and `journalctl --user -u rice-pleamar.service` for logs. `pleamar-shell launcher`, `menu`, `calendar`, `wallpapers`, `wifi`, `bluetooth`, `audio`, `battery`, and `close` address panels. check syntax with `pleamar --check ~/.config/pleamar/shells/material/material.plm`.

`pleamar-test start|stop|status` remains a compatibility wrapper around the Pleamar service. `stop` stops Pleamar without starting Quickshell.

`rice-session.target` starts the packaged `hyprpaper.service`, `hypridle.service` and `swaync.service`, plus `rice-osd.service` and `rice-clipboard.service`. local drop-ins give the packaged services the same restart policy as the other helpers. each helper restarts after two seconds even if it exits with status zero. inspect a helper with `systemctl --user status UNIT`; stop the group with `systemctl --user stop rice-session.target`. repeated startup leaves running helpers in place.

the Pleamar unit retains `PLEAMAR_FIFO=1` on this Intel/Hyprland setup. `hyprland.lua`, loaded from Hyprland's configuration, disables compositor animation for the `pleamar` layer namespace. Pleamar retains its spring, tilt and content animations. other layer surfaces retain their configured animations.

## layout and adapters

`material.plm` owns the bar and scene declarations, `parts/panels.plm` positions the cards and includes the individual views, and `palette.plm` defines colors. the bar uses a 42 px surface and reserves 42 px. separate overlays draw panels and delayed shortcut tooltips on the originating output. while a panel is open, its surface also draws tooltips so opening a tooltip keeps pointer and keyboard focus on the panel. panels share the bar palette, with larger headings and wider layouts. the control center groups connectivity into two tiles and keeps volume and brightness in separate cards. the launcher and wallpaper gallery use larger search and preview areas. panel backgrounds, borders, and text reference the bar colors; green and amber accents stay subtle. `material.luau` connects services, helpers, and input. application and wallpaper lists retain their full data in logic and render a bounded window through native scrolling layouts. keyboard and scroll rules target the originating output and active panel; inactive lists must not update the shared offset. the main surface requests exclusive keyboard access while a panel is open because the runtime applies its keyboard mode across surfaces. Escape releases that access when the panel closes. panel motion combines a spring reveal, a slight rotation around the upper edge, and delayed content. the overlay stays mapped through the closing transition; logic retains the panel until that transition ends and cancels stale close timers when reopening. buttons compress on press, launcher rows enter in sequence, and workspace indicators expand on springs.

The shell reuses rice resource, status, keyboard, and wallpaper tools. Its tray adapter preserves process identity checks and reads ItemIsMenu for menu-only icons. Its own Wi-Fi worker handles iwd and interactive BlueZ pairing; pleamar's built-in Bluetooth command backend is not used. Notifications stay with swaync. Audio uses pleamar's PulseAudio service and device IDs.

`helpers/desktop.py watch` keeps a Gio application catalog and a Unicode casefolded search index in memory. the launcher sends queries over stdin and receives JSON lines over stdout, with a generation number to discard obsolete results. searching has no debounce or per-query process startup. reopening the launcher uses the cached unfiltered list. Gio's application monitor refreshes the catalog when desktop entries change; the existing asset service still restarts Pleamar for icon updates. the worker restarts after two seconds if it exits.

hidden application IDs live in `~/.local/state/pleamar/material/hidden-applications.json`. the worker serializes hidden-state writes with search requests. terminal applications launch through kitty with their desktop entry's working directory. the helper expands `%c`, `%k`, `%i` and `%%`, removes file placeholders when launching without files, and rejects unknown field codes. it passes an argument list without invoking a shell. expansion follows the [desktop entry specification](https://specifications.freedesktop.org/desktop-entry/latest/exec-variables.html).

`helpers/wifi.py` drains stdin into a byte buffer before decoding JSON lines. split UTF-8 and consecutive commands do not depend on another read event. Bluetooth errors and pending replies stay separate from Wi-Fi state. PIN and passkey validation completes or rejects each agent reply once.

`helpers/gallery.py watch` owns one converter at a time. logic requests only missing previews for the current visible window and updates selection from cached paths. a new window replaces pending work; closing the gallery cancels conversion. revision keys include modification time and file size. the converter exits when its worker dies, including an uncatchable worker termination. refresh retries failed previews.

run `python -m unittest discover -s tests -v` from `~/dev/pleamar-shell` to check search, terminal arguments, connectivity command queues and preview cancellation. tests use temporary homes and mocked connectivity callbacks; they do not reconnect the network or pair hardware.

`helpers/idle-inhibit` maps a transparent 1 px Wayland layer surface with an empty input region and holds a Wayland idle inhibitor. `helpers/build-idle-inhibit` builds it with a C compiler, wayland-scanner, and wayland-client development files. The helper maps and synchronizes its surface before registering the inhibitor. Toggling keep awake starts or stops this helper; service shutdown releases it.

## runtime build

The executable lives at `~/.local/bin/pleamar`; source lives at `~/dev/pleamar`. the installed runtime and current runtime checkout retain both local patches. apply `runtime-text.patch`, then `runtime-performance.patch`, to a fresh pinned checkout before building. it snaps unscaled text to pixel boundaries and removes the extra glyph coverage boost.

`runtime-performance.patch` skips glass calculations for non-glass fills and includes shader validation and a visual fixture. the fixture matched all 307,200 pixels. repeated IPC search checks improved from about 22 to 18 ms median; the final animation probe improved p95 frame time from about 22.4 to 17.6 ms. the unchanged schedule renders more frames and uses about 0.05–0.06 more of one CPU core during the probe. scheduling experiments remain excluded. the [renderer study](https://github.com/chuh420/pleamar/blob/main/docs/optimization-2026-10-16.md) records measurements and limits.

Build with `taskset -c 0,1 nice -n 10 cargo build --release --locked -j 2` from the source folder, then install `target/release/pleamar` at `~/.local/bin/pleamar`. This source build installs the runtime alone. the running Pleamar service can remain active during a source build. install the new binary through a temporary file and rename it, then restart `rice-pleamar.service`. Build `helpers/idle-inhibit` with `helpers/build-idle-inhibit` before the first test. ImageMagick supplies cached gallery previews, including AVIF and BMP.

## manual quickshell session

`systemctl --user start rice-quickshell.service` replaces Pleamar with the retained Quickshell configuration. `systemctl --user start rice-pleamar.service` returns to Pleamar. the services conflict, so only one runs. panel shortcuts and asset refreshes continue to target Pleamar; a new login starts Pleamar.

## migration checks

Validated on the internal 1920×1080 output: scene syntax, complete panel drawing, 42 px reservation, wrapper IPC, application search and hidden-state persistence, wallpaper previews and navigation, Escape and pointer clicks outside panels, Wayland idle inhibition, service restarts and helper cleanup. A DBus test client exercised tray activation, 120-unit wheel steps, a 30-entry menu, nested entries, and custom quit mapping. Notifications remain owned by swaync.

Hardware interaction still needs a controlled check for Wi-Fi connections/password failures, Bluetooth pairing prompts, and audio device changes. Real application tray behavior and multiple outputs need user testing. the startup script now selects Pleamar; a full logout/login check remains pending.
