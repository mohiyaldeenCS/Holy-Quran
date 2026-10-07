# S5 Downloads

Status: **code ready; device measurement pending.** Question from
`docs/IMPLEMENTATION_PLAN.md`, M0.4: a resumable queue, Wi-Fi only, verify then
activate, update and rollback (`OF-04`, `OF-05`, `OF-06`). Real-network resume on a
real host waits for O-08 (M1.4).

Spike code: `spike/s5/`, removed before the merge (D-068); the last commit that holds
it is named here when the spike closes.

## What was built

- `SpikeDownloader` over `background_downloader` 9.5.9 (`allowPause`, `requiresWiFi`,
  retries, `Config.checkAvailableSpace`). The task id is derived from URL and target,
  so after a relaunch a call for the same file attaches to the plugin's task.
- `PackStore`: `staging/<id>/<version>/`, `packs/<id>/<version>/` and
  `packs/<id>/current`, which names the active and the previous version and is
  replaced by one atomic rename. A version is never overwritten; one previous version
  is kept; `recover()` at start-up removes leftover staging and temporary files and
  falls back when `current` names a missing version.
- `PackDownloadQueue`: sequential; manifest first, then its files, then
  `LocalPackRepository.verify`; a file rejected by its hash is fetched once more; a
  second rejection keeps the current version. A pack whose signature was not checked
  is activated and flagged (spike only; D-065 refuses it in a release).
- The device screen serves two synthetic packs (about 8 MiB each) from an in-app
  loopback server, throttled to 256 KiB/s, through a fixed port so a rescheduled task
  finds it after a relaunch. Profile builds allow cleartext to `127.0.0.1` and
  `localhost` only.

## Checked on Linux

`flutter test spike/s5`: 61 tests, run three times, all passing. The probe showed the
package's desktop path runs under `flutter test` once the target platform is set to
Linux, the task store is in memory and `Config.tempFilePath` is set. Through the real
downloader and the loopback server:

- clean download, verify, activate;
- a drop at 1.5 MiB resumes with `Range: bytes=N-` and 206; total bytes served stay
  within the file size plus 64 KiB;
- a drop at 100 KB restarts from 0: the package resumes only after more than 1 MiB
  has arrived (the same threshold as its Android runner);
- a file corrupted once is rejected and fetched again; twice, the pack is not
  activated and the previous version stays current;
- v1 to v2, then rollback to v1;
- two queued packs never overlap;
- recovery from leftover staging and `current.tmp`;
- an installed version is refused without any request.

What desktop cannot show: it ignores `requiresWiFi` and answers "not implemented"
to the space check. Both are device checks.

## Findings for M1.4

- The package reports no "waiting for Wi-Fi" state; the spike guesses it when a
  Wi-Fi-only task stays queued for 2 s. M1.4 needs a connectivity signal of its own
  if the screen must say so.
- Low space is recognised only by the plugin's message text and is retried first, so
  it surfaces after about 14 s with three retries.
- The space-check setting persists across launches on Android.
- Absolute paths are stable on Android; on iOS the container path moves, so M1.4
  uses the package's base directories rather than absolute paths.
- The main manifest has no `INTERNET` permission; the profile manifest adds it. A
  release build that downloads needs it in the main manifest.
- Writing services in M1.4 need names outside `lib/data/services/pack_*.dart`
  (pack write guard).
- After a rollback the newer version stays installed as the previous one, so
  "update" to it is refused as already installed; whether the product offers "switch
  back" instead is a question for M1.4.

## Device protocol (owner, Android, profile APK of D-069)

Open S5 and wait for "serving at http://127.0.0.1:47805, 256 KiB/s" (the first open
builds the packs and freezes the screen for a few seconds). "Wi-Fi only" is on.

1. **Wi-Fi only.** Wi-Fi off, mobile data on. Tap "Download v1": the log shows
   `queued`, then `waitingForNetwork`, and no `running`.
2. **Wi-Fi back.** Turn Wi-Fi on: `running` with percentages, then
   `activated 1 (... signature NOT CHECKED)`, and "Current: 1".
3. **Drop and resume.** Tap "Drop connection", then "Update to v2": `retrying`, then
   `running`; the server lines show a dropped 200 followed by `bytes=N-: 206`; then
   `activated 2 (previous 1)`.
4. **Rollback.** Tap "Rollback": "Current: 1, previous: 2". "Update to v2" is then
   refused as already installed.
5. **Force-stop and relaunch.** Copy the log, then Settings, Apps, holyquran, Storage,
   Clear storage. Open S5, tap "Download v1", force-stop the app about halfway,
   relaunch, open S5 at once and tap "Download v1" again: `attached to task ...` and a
   206 (resume) or a 200 (restart). Either is a result.
6. **Corrupt file.** Clear storage. Tap "Corrupt next file" once, then "Download v1":
   rejected, fetched once more, `activated 1`. Tap it twice before "Update to v2":
   `not activated (verification)`, current stays 1.
7. **Low space.** Tap "Space check above free" (the answer should be empty, not
   "not implemented"), then "Update to v2" (clear storage first if v2 is installed):
   after about 14 s, `not activated (insufficientSpace)`, current unchanged. Tap
   "Space check off".

Send: "Copy log", the phone model, Android version, and whether the Wi-Fi was
metered.

## Result

Pending the device run.
