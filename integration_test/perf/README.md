# Performance harness (P1-36, M1.11)

Measures the budgets of PRD §11 that a text-only build can reach: `NF-01` cold start
to the last reading position (2 s), `NF-02` scroll (60 fps, 99% of frames under
32 ms), `NF-03` offline search (300 ms) and `NF-05` the word and ayah sheets (200 ms).
`NF-04` and `NF-09` need a recitation and the player, and `NF-06`, `NF-07` are not
timings; the harness does not measure them. `NF-02` also names page turning
(«التقليب»); only the scroll of surah mode is measured, so turning pages stays a
pending human check of M1.11.

It runs the app's own start-up (`buildDependencies`, `AppStart`, the real screens)
over a synthetic pack of the real pack's shape (114 surahs, the long surah of 286
ayat, 604 pages), never Quran text. Every scenario prints its numbers as
`PERF_RESULT {json}` lines and hands the same objects to the host driver.

## What a number means

* A figure counts only from a **profile or release** build on a **phone**. A debug
  build, a run on a computer (`flutter test`, or `flutter drive -d linux|windows|macos`)
  and frames that are the cost of each pump of a widget test are informative: the
  summary says so.
* The first launch of an install builds the pack (`prepared: true`); the summary
  leaves that run out. Runs after it find the pack as an earlier launch left it.
* `cold_start` runs from the first frame the app is asked to draw (the splash) to the
  first frame in which the reader shows the saved ayah scrolled into view. The
  engine's own start-up before Dart's entry point is not in it. The whole-process
  figure of the product (`adb shell am start -W`, its Total time) needs the bundled
  base pack (B0.2) and stays a pending human check of M1.11.
* `scroll` records the engine's frame timings (vsync to raster end) while the
  longest surah scrolls at 1500 px/s for 10 s, three runs in one process. If the
  list stops early, `travelledShare` falls below 0.95 and the check is missed.
* `search` is the first query of a screen (the index is built when the screen opens;
  that time is `screenReadyMs`); `search_warm` is the second.
* `word_sheet` and `ayah_sheet` are the median of ten openings, from the tap to the
  first frame that draws the sheet's text; the worst is kept beside it.
* The verdict of a check is on the median of its runs, with the worst run beside it,
  except `travelledShare`, where every run must hold: one stopped scroll is a bad
  run. Results are held apart by device (platform and OS version), so two phones
  are never pooled, and the summary prints each device's lines.

## On a reference device (owner)

The reference devices are a mid-range Android phone with 4 GB of memory and the oldest
iPhone that runs the minimum iOS (PRD §11). Android needs the Flutter SDK of D-154
and USB debugging; the iPhone needs a Mac with Xcode and a signing team, and the
same commands.

Record first, for each phone: model; Android or iOS version; memory; refresh-rate
setting; system font size; battery level (above 50%) and whether battery saver or
low-power mode is on; whether the phone was warm from other use; the commit
(`git rev-parse --short HEAD`).

1. Connect the phone, `flutter devices` shows its id.
2. Prepare: run the cold-start target once (step 4, first run). It builds the pack;
   its result is marked `prepared` and is not counted.
3. Close other apps, leave the screen on, and do not touch the phone during a run.
4. Run each target, from the repository root:

   ```
   flutter drive --profile -d <id> --driver=test_driver/perf_driver.dart --target=integration_test/perf/cold_start_test.dart
   flutter drive --profile -d <id> --driver=test_driver/perf_driver.dart --target=integration_test/perf/scroll_test.dart
   flutter drive --profile -d <id> --driver=test_driver/perf_driver.dart --target=integration_test/perf/search_test.dart
   flutter drive --profile -d <id> --driver=test_driver/perf_driver.dart --target=integration_test/perf/sheets_test.dart
   ```

   * Cold start: run the first command **eleven times** (one preparing run and ten
     counted). Each run is a new process: `flutter drive` stops the app at its end.
     Force stop it from the phone's app settings if it is still listed as running.
   * Search: run its command **five times**, each in a new process, because the
     first query of a process builds the index.
   * Scroll and sheets: once each.
   * Do not uninstall the app between runs: the pack lives in its storage.
5. Each run writes `build/perf/<scenario>-<time>.log`. Use a clean `build/perf/` for
   each phone (a stale log of an older commit would be counted) or pass only that
   phone's files. Summarise:

   ```
   dart run test_driver/perf_summary.dart --out build/perf/report.json build/perf/*.log
   ```

   The output has one line per check: `MET`, `MISSED`, `INFORMATIVE` or
   `NOTMEASURED`, with the median, the worst run and the limit.

Send: `build/perf/report.json`, the `build/perf/*.log` files, the lines the summary
printed, and the phone details above. Note any run that was disturbed (a call, a
notification, the phone getting hot) instead of dropping it.

`NF-01`'s cold start is also to be seen once by hand on the real app when the base
pack is bundled: force stop, open from the icon, time to the saved ayah with a
stopwatch video or `adb shell am start -W`.

## On a computer (informative only)

`flutter test test/perf` runs every scenario on a small pack, so that they keep
working; `--dart-define=PERF_SIZE=full` uses the full-size pack. The numbers come
from a debug build whose frames are never drawn and say nothing about a phone.
`flutter drive -d windows --profile ...` takes the same commands as a phone and
shows how the harness behaves, but its figures stay informative.
