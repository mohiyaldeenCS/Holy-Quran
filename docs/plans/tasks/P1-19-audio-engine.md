# P1-19 — Audio engine and player state (M1.9)

Wave 2 · Agent `audio-builder` · Key 1 · Cap $35 · Base `main` · Needs: P1-05, P1-06, P1-08.

## Why

- `AU-05` controls; `AU-06` «السرعة من 0.5 إلى 2.0 بخطوة 0.25 مع حفظ طبقة الصوت»; `AU-07`
  fade; `AU-12` «البث مع تحميل مسبق للمقطع التالي»; `AU-15` «التشغيل في الخلفية، والتحكم من
  شاشة القفل والإشعار وأزرار السماعات»; `AU-22` «مكالمة أو نزع سماعة يوقفان مؤقتًا، ثم
  المتابعة بحسب سياسة النظام»; `AU-04` and `AU-17` executed; `AX-07`.
- `NF-04` «ثانية للمنزَّل، و3 ثوانٍ للبث على شبكة الجوال»; `NF-09` sixty minutes; `NF-12`
  «خدمة تشغيل وسائط أمامية وإذن إشعارات على Android، ووضع الصوت في الخلفية على iOS».
- Criteria: «الانتقال بين آيتين متتاليتين في ملف سورة متصل بلا فجوة مسموعة»; «التشغيل
  يستمر 60 دقيقة والشاشة مقفلة دون انقطاع»; «عند فقد الشبكة أثناء البث تظهر «تعذّر
  الاتصال» ويُحفظ الموضع».

Read D-111 in `docs/plans/PHASE1.md` §6 and `docs/spikes/S3-background-audio.md`
(Android settings, `androidStopForegroundOnPause`, headset clicks, Android 15 audio
focus).

## Plan first

Ask `flutter-architect` for the engine plan. Port spike S3 from the commit its page
cites (`git show <sha>:spike/s3/…`).

## Do

Work in this order: 2 over a fake engine first, then 1, then 4 and 5. If the budget
runs short, commit what is done and report where you stopped.

1. `AudioEngineService` and `AudioHandler` (the only importers of `just_audio`,
   `audio_service`, `audio_session`): a playlist of plan segments with the next one
   preloaded, clips of surah files when the plan has boundaries, speed with pitch
   kept, seek, a fade for the sleep timer, lock-screen, notification and headset
   controls, interruptions and unplugging pause.
2. `PlayerRepository`: runs P1-08's plan and rules, holds the app-wide state (plan,
   segment, address, position, playing, speed, repeat counter, queue, error) as a
   `Listenable`; queue add, reorder and remove; on network loss while streaming, the
   state `connectionFailed` with the position kept.
4. Media metadata carries the surah name from the pack (a pack-text sink, entry
   citing D-114) and the reciter's name.
5. Android: `AndroidManifest.xml` and `MainActivity.kt` as S3 left them (permissions,
   the audio service and media button receiver, `AudioServiceActivity`); the
   notification permission asked at first playback on Android 13 and later, by the
   means step 0 recorded (recommended: a method channel in `MainActivity.kt`); iOS:
   `UIBackgroundModes` `audio` in `Info.plist`.
6. Fill `lib/config/providers/audio_providers.dart`; fake
   `testing/fakes/fake_player_repository.dart`.

## Tests

With a fake engine behind the service's interface: repeat counts exact, stop-after,
sleep timer before the others, continue across surahs, queue operations, network loss
keeps the position, speed steps. The plugins and the 60-minute, lock-screen, headset
and call behaviour are pending device checks.

## Acceptance

- `dart format .` changes nothing, `flutter analyze` reports no issues, and
  `flutter test --exclude-tags golden test tools/gen/test` passes (add `spike` if that
  folder exists). Run all three before the last commit, fix what fails, and run them
  again. Never weaken, skip or delete a test to make it pass.
- Golden images are made only by the CI `goldens` task (D-056). Write new golden tests
  tagged `golden`; never create or commit a `.png` file. A new golden test without its
  image is expected.
- Each acceptance criterion quoted above is reported as met (with its test), partial
  (with the reason) or a pending human check (device, reviewer or owner).

## Self-review

Through the Task tool, run `code-reviewer` on your whole diff. Fix every blocking
and should-fix finding, re-run the checks, and ask again until none remains. Say in
the report which nits you left and why.

## Files

### You own
- `lib/data/services/audio_engine_service.dart`
- `lib/data/services/audio_handler.dart`
- `lib/data/repositories/player_repository.dart`
- `lib/domain/models/player_state.dart`
- `lib/config/providers/audio_providers.dart`
- `android/app/src/main/AndroidManifest.xml` and `android/app/src/main/kotlin/**/MainActivity.kt` (handed over)
- `ios/Runner/Info.plist` (handed over)
- `testing/fakes/fake_player_repository.dart`
- The tests that mirror these files (same path under test/, ending in _test.dart)
- `test/guards/allow/pack_text/sinks/p1-19-media-metadata.txt`

### Do not touch
P1-08's files (report a needed change), `lib/ui/`, `pubspec.*`, other Android files.

## Rules

- `CLAUDE.md` and `docs/WORKFLOW.md` apply in full. Quran text comes only from packs,
  by address, through `QuranText`, `SurahName` or a sink listed under
  `test/guards/allow/`; it is never typed, pasted, trimmed, normalised or split by the
  app. Tests use the synthetic packs of `testing/packs/` and obviously synthetic text.
- No generated content. The identity is closed. No Arabic wording of your own: use
  only keys in `lib/l10n/app_ar.arb`; if one you need is missing, leave that element
  out and list it in the report.
- Edit only the files under "You own"; every file listed there is handed over to you
  for this task, whatever your agent file says. If another file must change, stop that
  part and report it. A gallery title or sample label reuses an existing key. Never edit `docs/PROJECT_STATUS.md`, `docs/DECISIONS.md`, `.github/`, or
  `pubspec.*`.
- Few comments, saying why; small files; no dead code or speculative options; no
  literal colours, font names or inline design numbers in feature code.
- Never print, write or commit secrets or environment variables; do not run `env`,
  `printenv` or `set`.
- Commit on the current branch only. Do not push, open pull requests, change remotes or
  call the GitHub API.

## Commits

- `feat(audio): audio engine with background playback and media controls (AU-15)`
- `feat(audio): player state, queue and network loss (AU-17)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
