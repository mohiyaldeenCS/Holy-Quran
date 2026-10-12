# P1-31 — Word sheet (text and tafsir tabs) and mini ayah sheet (M1.6, M1.7, M1.9)

Wave 4 · Agent `ui-builder` · Key 1 · Cap $30 · Base `main` · Needs: P1-23, P1-24,
P1-28, P1-30.

## Why

`ST-01` «ورقة الآية المصغّرة: الآية، التفسير، ملاحظاتي، الصوت»; PRD §7.4: «زر «دراسة» في
شريط الأدوات يفتح ورقة الآية المصغّرة في المرحلة 1»; `LX-01` «ورقة الكلمة ... تبويباتها
بحسب الحزم المنزّلة» (text, and now tafsir); `LX-11` «كل حقل يحمل شارة مصدره. الحقل الذي لا
بيانات له لا يظهر، ولا تُعرض قيمة مولَّدة»; `NF-05` 200 ms. `ST-01` and `LX-01` are
finished only when their last part arrives (`docs/IMPLEMENTATION_PLAN.md`, notes).

## Do

1. Ayah sheet (`/sheet/ayah/:address`, in `lib/ui/features/sheets/ayah_sheet/`):
   sections in order — the ayah (`QuranText`); the default tafsir's passage
   (`TafsirText` and `SourceBadge`); my notes, with a way to add one
   (`/sheet/note/:address`); audio, playing this ayah through
   `/sheet/play-options/:address`. A section with no data is not shown.
2. Word sheet (`/sheet/word/:address`, opened by P1-23's word tap): `WordSheet` with
   the text tab, and the tafsir tab only when a tafsir is installed, with the passage
   of the word's ayah and its badge; no row without data. Update `WordSheet` only as
   its reference allows.
3. Ayah toolbar: add the study action (to the ayah sheet) and, if P1-39 has added the
   copy and share icons, those two actions (to P1-12's routes).
4. `lib/routing/routes/sheets_routes.dart` for both sheets; metrics in
   `ayah_sheet_metrics.dart`.

## Tests

Sections appear only with data; the sheets open within the budget on the CI runner
(report the numbers); the word sheet shows only its text tab without a tafsir; the
tafsir tab appears with an installed synthetic tafsir; ayah
and passage bytes unchanged. Golden tests of both sheets.

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
- `lib/ui/features/sheets/`
- `lib/routing/routes/sheets_routes.dart`
- `lib/ui/core/widgets/ayah_toolbar.dart`
- `lib/ui/core/widgets/word_sheet.dart`
- `lib/ui/core/metrics/ayah_sheet_metrics.dart`
- `test/ui/features/sheets/`, `test/ui/core/widgets/word_sheet_test.dart`, `test/ui/core/widgets/ayah_toolbar_test.dart`

### Do not touch
`lib/ui/features/mushaf/` (P1-32 this wave), `lib/data/`, `lib/l10n/`.

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

- `feat(ayah): mini ayah sheet with ayah, tafsir, notes and audio (ST-01)`
- `feat(word): tafsir tab in the word sheet (LX-01)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
