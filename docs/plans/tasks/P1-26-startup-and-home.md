# P1-26 — Start-up at the last position, «أكمل الاستماع», bookmarks door, integrity alert (M1.1, M1.2, M1.9)

Wave 3 · Agent `ui-builder` · Key 2 · Cap $20 · Base `main` · Needs: P1-14, P1-15,
P1-16, P1-18, P1-19, P1-25.

## Why

- `RD-13` «فتح التطبيق على آخر موضع (إعداد)»; `NF-01` «من فتح التطبيق إلى ظهور آخر موضع
  قراءة، تشغيلًا باردًا | ثانيتان».
- `AU-16` «حفظ آخر موضع استماع (التلاوة، السورة، الآية، الموضع الزمني) ومتابعته»; the home
  row «أكمل الاستماع» (PRD §7.1).
- The bookmarks door, now that bookmarks ship (PRD §7.1: a door only for a shipped
  feature). PRD §9.5: the integrity alert when the base pack fails.

## Do

1. `startup_redirect.dart`: when "open at the last position" is on and a position
   exists, start on `/mushaf/read/<address>`; keep P1-15's first-run rule first.
2. `lib/domain/use_cases/record_listening_position.dart` (delegate to `data-builder`):
   from the player's state, save on pause, on stop and every 10 s while playing
   (D-106); register it in `lib/config/providers/audio_providers.dart`.
3. Home: `ContinueListeningRow` with the surah, ayah and reciter of the last listening
   position; a tap resumes there. The bookmarks door to `/more/bookmarks`.
4. At start, if the base pack is failed, show the integrity alert (P1-25's
   component) instead of the reader; its wording is Appendix C: wire the state and
   report.

## Tests

Start-up lands on the reader at the saved ayah when the setting is on, on home when
off; the listening position is saved at the three moments and resumed; the row hides
with no position; the door opens bookmarks; a failed base pack never shows text.

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
- `lib/ui/features/home/`
- `lib/routing/startup_redirect.dart`
- `lib/routing/routes/home_routes.dart`
- `lib/domain/use_cases/record_listening_position.dart`
- `lib/config/providers/audio_providers.dart`
- `lib/ui/core/metrics/home_metrics.dart`
- `test/ui/features/home/`, `test/routing/startup_redirect_test.dart`, `test/domain/use_cases/record_listening_position_test.dart`

### Do not touch
`lib/data/`, `lib/l10n/`, `lib/ui/core/widgets/`, P1-19's files.

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

- `feat(home): open at the last reading position (RD-13)`
- `feat(home): continue listening from the last position (AU-16)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
