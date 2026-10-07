# S3 Background audio — playback part

Status: **code ready; device measurement pending.** Question from
`docs/IMPLEMENTATION_PLAN.md`, M0.4: does playback continue for 60 minutes with the
screen locked, with lock-screen, notification and headset controls (`AU-15`,
`NF-09`)? Interruptions (`AU-22`) are watched in the same session, not a gate. The
highlight part of S3 waits for timing data (B0.5).

Spike code: `spike/s3/`, removed before the merge (D-068); the last commit that holds
it is named here when the spike closes.

## What was built

- **Sound.** No recitation is used: none has a rights record yet (O-04). A tone is
  generated at run time (`tone_wav.dart`): 16 kHz mono 16-bit PCM, a quiet 220 Hz
  tone with a 1 kHz beep of 250 ms at the start of every 10 s, so a gap can be heard.
  The queue is 12 tracks of the same 5 min 50 s file: 70 minutes, with track changes.
- **Handler.** `SpikeAudioHandler` (`audio_service` 0.18.19 over `just_audio` 0.10.6,
  `audio_session` 0.2.4 with the speech configuration): play, pause, stop, seek, next,
  previous; headset clicks counted within 400 ms (one toggles, two or more skip, so a
  single click acts 400 ms late); unplugging pauses; an interruption pauses and
  resumes only after a transient loss ended by the system.
- **Log.** A sample every 5 s (wall clock, monotonic elapsed time, position, playing,
  state, track) appended to `<app support>/spike/s3-log.jsonl` with a flush, so a
  killed process keeps its log. The analyser reports the longest uninterrupted run,
  gaps, stalls, position jumps, clock jumps and track changes, as numbers only.
- **Android settings** (revert in the cleanup commit; M1.9 brings back what it keeps):
  - `AndroidManifest.xml`: `xmlns:tools`; permissions `WAKE_LOCK`,
    `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS`;
    the `com.ryanheise.audioservice.AudioService` service
    (`foregroundServiceType="mediaPlayback"`, exported, `MediaBrowserService` action);
    the `MediaButtonReceiver` (`MEDIA_BUTTON` action). As in the package README.
  - `MainActivity` extends `AudioServiceActivity`.

## Checked on Linux

`flutter test spike/s3`: 15 tests (WAV header, length and beep positions; the
analyser on made-up logs with a gap, a stall, a track change and a clock jump).

Not checked here: the Android build (no Android SDK; the CI build check of D-069
covers it), and everything on a device.

## Points to watch on the device

- `POST_NOTIFICATIONS` is declared but not requested at run time; Android 13 and later
  exempt media-session notifications. If no notification appears, note it and enable
  notifications in settings.
- `androidStopForegroundOnPause` is left at its default (true). Resuming from the
  background after a pause (headset, call) may throw
  `ForegroundServiceStartNotAllowedException` on Android 12 and later; the protocol
  tests it and the outcome sets the M1.9 value.
- `AudioServiceActivity` supplies the Flutter engine, so the Dart isolate outlives
  the activity: after back and reopen the app keeps its state. Cold-start
  measurements (S1, NF-01) force-stop the app first.
- From Android 15, an app that is neither in front nor running a foreground service
  cannot take audio focus; with `androidStopForegroundOnPause` true, resuming after
  a call may fail for that reason too. The call step records whether it resumes.
- Notification and lock-screen commands look the same in the log; only headset
  presses are logged as clicks. The owner's notes tell them apart.

## Device protocol (owner, Android, profile APK of D-069)

Preparation: battery above 50%, normal battery settings (note whether battery saver
is on); wired headphones with a button or a Bluetooth headset; a second phone to call
this one. Open the app, choose S3.

A. **70 minutes locked** (`NF-09`, `AU-15`). Press Start run: the tone, a beep every
10 s and a media notification. Lock the screen and leave the phone for 70 minutes.
Record the start time, any break or silence and when, when the sound stopped, and the
battery at start and end. Unlock, open S3, press Copy report and send the text.

B. **Lock-screen and notification controls.** Start a new run (copy A's report
first). On the lock screen: pause, wait 2 minutes, play, next, previous. Then the
same from the notification shade, unlocked. Record for each: did it work, and how
quickly.

C. **Headset.** Screen locked. One click pauses; one click resumes about half a second
later; a double click skips to the next track; pause, wait 2 minutes locked, click:
did it resume?

D. **Unplugging** (`AU-22`). While playing through the headphones, unplug them: did it
pause, and did anything come from the speaker?

E. **A call** (`AU-22`). While playing with the screen locked, call the phone. Answer,
talk 30 seconds, hang up: did playback resume by itself, and after how long? Repeat
with a rejected call. Press Copy report and send it.

Send: phone model, Android version and memory; whether the notification appeared; the
two copied reports; the notes per step.

## Result

Pending the device run.
