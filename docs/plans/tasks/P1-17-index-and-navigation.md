# P1-17 — Index, go-to sheet, context sheet, ayah cards (M1.3)

Wave 2 · Agent `ui-builder` · Key 1 · Cap $30 · Base `main` · Needs: P1-04, P1-05,
P1-09, P1-10.

## Why

- `NV-01` «فهرس السور: الرقم داخل نجمة الربع، الاسم، مكية أو مدنية، عدد الآيات، صفحة
  البداية، وشارة «آخر قراءة»»; `NV-02` «فهارس الأجزاء (30) والأحزاب (60) وأرباعها (240) مع
  أول آية ورقم الصفحة»; `NV-03` (go-to, parsing in P1-10); `NV-05` «ورقة سياق الآية: آية،
  3 آيات، 5 آيات، السورة. وزرها الأساسي «افتح في المصحف»»; `RD-14` ayah cards in lists
  and context.
- Criterion: «كل إدخال صالح ينقل إلى موضعه الصحيح. الإدخال غير الصالح يُرفض بجملة تسمّي
  السبب».
- D-088 moved `ContextSheet` here. The M0.2 review: the context sheet justifies its
  compact Quran text at 23 px (`.qk-ctx .qk-quran-compact`), while `QuranText` renders
  compact start-aligned (D-060), so the sheet needs its own variant.

Drawn: the index (Screens2 board), the context sheet (Search board and
`design/design-system/components/ContextSheet`).

## Do

1. Index screen (`/mushaf/index`): «الفهرس» and its summary; tabs «السور»، «الأجزاء»،
   «الأحزاب»; `SurahListItem` rows with «آخر قراءة» on the last-read surah; juz rows
   with first ayah and page; hizb rows with their rubs («ربع»). Each row opens the
   reader at its first ayah.
2. Go-to sheet (`/sheet/goto`): «اذهب إلى» with the six targets and number input in
   both digit systems, through P1-10; "no such ayah" shown with «لا توجد آية {ayah} في
   {surah}». The other errors have no wording (Appendix C): the input is refused
   without a sentence; report it as partial.
3. `lib/ui/core/widgets/context_sheet.dart` from the component reference, with the
   multi-ayah text composed with P1-09's paragraph builder (D-088;
   `QuranText` stays as it is, D-060); route `/sheet/context/:address`: amounts «آية»، ayah counts 3 and 5 through
   `ayahCount`, «السورة»; «افتح في المصحف» to the reader.
4. Ayah cards in the context list with `AyahRow`.
5. `lib/ui/core/widgets/search_result.dart`: the expanded state becomes a parameter
   owned by the caller (M0.5 review: a card scrolled away and back collapsed).
6. Gallery: `ContextSheet` and the caller-owned `SearchResult` in
   `study_search_gallery.dart`; a new colour pair as an entry under
   `test/guards/allow/contrast/`.
7. `lib/routing/routes/index_routes.dart`; metrics in `index_metrics.dart`.

## Tests

The three index tabs on a synthetic pack (counts from the pack, not constants); last
read badge; every go-to form opens the right address; the error sentence; context
amounts; the context sheet draws the pack's bytes unchanged. Golden tests of the index,
go-to and context sheet.

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
- `lib/ui/features/index/`
- `lib/ui/core/widgets/context_sheet.dart`
- `lib/ui/core/widgets/search_result.dart`
- `lib/ui/core/metrics/index_metrics.dart`
- `lib/routing/routes/index_routes.dart`
- `lib/ui/core/gallery/sections/study_search_gallery.dart`
- `test/guards/allow/contrast/p1-17-*.txt`
- `test/ui/core/gallery/study_search_gallery_test.dart`
- `test/ui/features/index/`, `test/ui/core/widgets/context_sheet_test.dart`, `test/ui/core/widgets/search_result_test.dart`

### Do not touch
`lib/l10n/`, `lib/data/`, the gallery's other sections, other features.

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

- `feat(index): surah, juz and hizb indexes (NV-01)`
- `feat(index): go-to sheet (NV-03)`
- `feat(index): ayah context sheet (NV-05)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
