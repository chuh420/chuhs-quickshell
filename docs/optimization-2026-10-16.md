# renderer optimization study

the installed runtime combines the existing text patch with `runtime-performance.patch`. the latter skips glass calculations for non-glass fills, includes shader validation and adds a visual fixture. FIFO and the existing rendering schedule remain in use. no animations or GPU synchronization checks were removed.

## search response

the first benchmark used two IPC invocations and accepted a zero result count. the shell clears its list before the worker replies, so that check could finish before the search completed. its reported candidate regression did not establish an input regression.

the corrected benchmark alternates queries with distinct nonzero result counts, sends the query and wait through one invocation, and varies the interval with seeded jitter. two runs per binary, ordered before/candidate/candidate/before, each checked 60 updates:

| runtime | median, run 1 | median, run 2 | p95, run 1 | p95, run 2 |
| --- | --- | --- | --- | --- |
| previous text patch | 21.70 ms | 22.07 ms | 35.43 ms | 34.65 ms |
| text patch and fill optimization | 17.55 ms | 18.18 ms | 28.86 ms | 27.52 ms |

these measurements cover command startup through the renderer observing the completed result count. they do not measure keyboard-to-display latency. search correctness, Unicode matching and result replacement have separate helper tests and live checks. the persistent search worker, which removed process startup and the 60 ms debounce, remains the main search improvement.

## rendering and cost

a 24-cycle run alternated the launcher and control center over 29 seconds:

| metric | previous runtime | fill optimization |
| --- | --- | --- |
| measured frames | 1149 | 1478 |
| median frame | 18.1 ms | 14.0 ms |
| p95 frame | 22.5 ms | 17.6 ms |
| p99 frame | 23.9 ms | 18.9 ms |
| maximum frame | 25.4 ms | 20.6 ms |
| frames over 1.5 display periods | 2 (0.2%) | 0 |
| CPU, fraction of one core | 21% | 26% |
| RSS | 87 MB | 87 MB |
| reported GPU memory | 35 MB | 35 MB |

the earlier baseline had 8.9% late frames; the later baseline improved too, so that percentage is not a stable estimate of the patch benefit. the first final baseline overlapped a 1.2-second helper test run. a subsequent 24-cycle baseline without that overlap confirmed median 18.0 ms, p95 22.4 ms and CPU 20% of one core, with one late frame in 1120; RSS was 108 MB. both sets of search comparisons ran without builds or tests. these short probes describe this Intel N150/Hyprland session, rather than a general performance guarantee.

the fill optimization allows the unchanged schedule to render more frames, including more than the display refresh rate. animation CPU therefore rises by about 0.05–0.06 of one core across these runs. closed-panel CPU samples were equal at 5.12% of one core while terminal titles and resources updated. the change improves response and frame time; it does not claim lower animation power consumption.

## verification and rejected changes

all 307,200 pixels in the static fixture matched between the original and optimized runtimes. the fixture covers plain fills, strokes, shadows, gradients, merged shapes, rotation, opacity, glass and text. this verifies those cases, rather than every scene or animation frame.

53 runtime tests passed, one hardware-dependent test remained ignored, and 257 language checks passed. fourteen isolated shell tests covered search, terminal arguments, connectivity and gallery cleanup. the final source build matched the measured fill-only binary byte for byte. after installation, all eight panels opened and closed, and the launcher returned empty and nonempty search results.

swapchain rendering worsened stalls and was rejected. native-buffer clock pacing reduced excess frames, but its response checks did not justify changing the schedule; it remains excluded. the installed patch contains only the fill optimization and its verification assets.

raw reports, comparison captures and the original executable remain in `~/.local/state/pleamar/optimization-2026-10-16/`. `tools/measure-panels.py`, `tools/measure-search.py` and `tools/compare-runtime.py` reproduce the checks. restore `pleamar.before` through a temporary file and rename, then restart `rice-pleamar.service` to roll back the renderer alone.

live Wi-Fi reconnection, Bluetooth pairing, audio device changes, logout/login and multiple displays remain outside this audit's validation. the hardware tests require a controlled session.
