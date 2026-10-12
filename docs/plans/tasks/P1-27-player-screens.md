# P1-27 — Full player, mini player, recitation picker (M1.9)

Wave 3 · Agent `ui-builder` · Key 1 · Cap $30 · Base `main` · Needs: P1-13, P1-19.

## Why

- `AU-01` «اختيار التلاوة مع عرض الرواية والنمط وحالة التنزيل وتوفر توقيت الكلمات»;
  criterion «لا تظهر في القائمة تلاوة ليس لها سجل حقوق مكتمل».
- `AU-05` «تشغيل، إيقاف مؤقت، متابعة، إيقاف، الآية التالية والسابقة، السورة التالية
  والسابقة، والتنقل بشريط التقدّم»; `AU-06` speed on the player.
- PRD §7.7: «صف التلاوة: القارئ، الرواية، النمط، حالة التنزيل، توفر توقيت الكلمات» from
  `ResourceRow`. PRD §7.8: the mini player has five buttons; next and previous surah
  live in the full player. `LV-03` criterion: the mini player shows only while playing.

Drawn: the player (Screens2 board), `MiniPlayer`.

## Do

1. Full player (`/listen`, replacing the placeholder): the emerald card of the
   Screens2 board — surah and ayah (`SurahName`), reciter, speed, gold progress with
   seeking, the five buttons, «الآية {ayah} من {total}», the range line, repeat and
   silence labels. Its repeat, sleep, range and queue buttons open P1-28's routes by
   path. Stop and next and previous surah are icons of D-051: add them only if
   `IconName` has them (P1-39); otherwise report.
2. Mini player above the tab bar in `lib/ui/core/tab_shell.dart`, only while playing.
3. Recitation picker (`/listen/recitations`, opened by «تغيير»): rows with reciter,
   riwaya, style, download state, «توقيت كلمات» where available. With no recitation
   in the catalogue the list is empty; its empty sentence is Appendix C.
4. Gallery: the recitation row and player states in `audio_gallery.dart`.
5. `lib/routing/routes/listen_routes.dart`; metrics in `player_metrics.dart`.

## Tests

Controls call the player; seeking; speed shown; the mini player appears and goes with
playback; only rights-complete recitations listed (fake repository); four themes and
200%. Golden tests of the player, mini player in the shell, and picker.

## Acceptance

- `dart format .` changes nothing, `flutter analyze` reports no issues, and
  `flutter test --exclude-tags golden test tools/gen/test` passes (add `spike` if that
  folder exists). Run all three before the last commit, fix what fails, and run them
  again. Never weaken, skip or delete a test to make it pass.
- Golden images are made only by the CI `goldens` task (D-056). Write new golden tests
  tagged `golden`; never create or commit a `.png` file. A new golden test without its
  image is expected.
- The acceptance checklist of `docs/DESIGN_SYSTEM.md` holds for every widget and
  screen you touched: four themes, right to left, 200% text, 48 hit areas, labels,
  focus ring, reduce motion, Arabic-Indic digits, strings from the ARB file.
- Each acceptance criterion quoted above is reported as met (with its test), partial
  (with the reason) or a pending human check (device, reviewer or owner).

## Self-review

Through the Task tool, run `code-reviewer` on your whole diff and `identity-auditor` on every UI change. Fix every blocking
and should-fix finding, re-run the checks, and ask again until none remains. Say in
the report which nits you left and why.

## Files

### You own
- `lib/ui/features/listen/views/listen_screen.dart`, `player_screen.dart`, `recitation_picker_screen.dart`
- `lib/ui/features/listen/view_models/player_view_model.dart`, `recitation_picker_view_model.dart`
- `lib/ui/core/tab_shell.dart`
- `lib/routing/routes/listen_routes.dart`
- `lib/ui/core/metrics/player_metrics.dart`
- `lib/ui/core/gallery/sections/audio_gallery.dart`, `test/ui/core/gallery/audio_gallery_test.dart`
- `test/ui/features/listen/player_screen_test.dart`, `recitation_picker_screen_test.dart`, `test/ui/core/tab_shell_test.dart`

### Do not touch
`lib/ui/features/listen/views/controls/`, `lib/ui/features/listen/view_models/controls/`
(P1-28), `lib/data/`, `lib/l10n/`.

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

- `feat(audio): full player and mini player (AU-05)`
- `feat(audio): recitation picker (AU-01)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
