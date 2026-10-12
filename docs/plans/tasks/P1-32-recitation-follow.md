# P1-32 — Following the recitation in the reader (M1.10)

Wave 4 · Agent `ui-builder` · Key 2 · Cap $30 · Base `main` · Needs: P1-23, P1-27.

## Why

`SY-01` «تمييز الآية المسموعة بخلفية وبامتلاء فاصلتها»; `SY-03` «التمرير التلقائي في وضع
السورة ... إذا مرّر المستخدم يدويًا يتوقف التتبع ويظهر زر «عُد إلى موضع التلاوة»»; `SY-04`
«التمييز يتبع سرعة التشغيل»; `SY-05` «وضع الحامل: منع إطفاء الشاشة مع التتبع التلقائي وإخفاء
الواجهة»; `RD-16` during recitation. Criterion (ayah part): «انحراف تمييز الآية لا يزيد عن 250
مللي ثانية». D-112 (`docs/plans/PHASE1.md` §6): the recited ayah comes from the plan's
`ayahStarted` events, which need no timing for recitations served per ayah; word
highlighting (`SY-02`) is blocked on registry row 6 and is not built. O-12: the number
inside the filled marker is 3.1:1 in sepia; keep the identity's value and list it.

## Do

1. The reader listens to `PlayerRepository`: the recited ayah gets P1-22's recited
   highlight and filled marker; the reader scrolls to keep it in view.
2. A manual scroll stops following and shows «عُد إلى موضع التلاوة», which scrolls back
   and resumes following.
3. Highlight timing comes from player events, so it follows any speed; measure the lag
   between event and paint on the CI runner and report it.
4. Stand mode: keep awake, follow and hide the interface. Its toggle has no wording
   (Appendix C): build the state and report.
5. `ReaderPlayerBar` in the reader while playing; keep-awake while reciting.
6. Gallery: the following states in `mushaf_gallery.dart`; the marker pair as an entry
   under `test/guards/allow/contrast/` with its O-12 exception.

## Tests

With a fake player: the highlight moves with `ayahStarted`; auto-scroll; manual scroll
stops following and the button returns; speed changes keep the highlight in step;
keep-awake on while reciting. Golden tests of the following states.

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
- `lib/ui/features/mushaf/`
- `lib/routing/routes/mushaf_routes.dart`
- `lib/ui/core/widgets/reader_player_bar.dart`
- `lib/ui/core/metrics/reader_screen_metrics.dart`
- `lib/ui/core/gallery/sections/mushaf_gallery.dart`, `test/ui/core/gallery/mushaf_gallery_test.dart`
- `test/guards/allow/contrast/p1-32-*.txt`
- `test/ui/features/mushaf/`, `test/ui/core/widgets/reader_player_bar_test.dart`

### Do not touch
`lib/ui/core/reader/`, `lib/data/`, `lib/l10n/`, `lib/ui/features/sheets/`.

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

- `feat(av-sync): highlight and follow the recited ayah (SY-01)`
- `feat(av-sync): return to the recitation and stand mode (SY-03)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
