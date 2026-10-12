# P1-23 — Reader gestures, ayah toolbar, margin indicators (M1.2, M1.6)

Wave 3 · Agent `ui-builder` · Key 1 · Cap $30 · Base `main` · Needs: P1-14, P1-18,
P1-22.

## Why

- PRD §7.4: «لمسة على فاصلة الآية | أدوات الآية»; «لمسة مطوّلة على آية | اختيار الآية
  وشريط أدواتها: تشغيل، علامة، دراسة، نسخ، مشاركة»; «لمسة على كلمة | بسيط: إظهار الواجهة
  أو إخفاؤها. متوسط ودراسة: ورقة الكلمة»; «لمسة على الهامش | إظهار الواجهة أو إخفاؤها»;
  «القرص | وضع السورة: حجم النص».
- `RD-07` (surah sizes by pinch), `RD-09` toggled by the margin tap, `LV-03` with its
  criterion «في المستوى البسيط لا يظهر في شاشة القراءة غير شريط الموضع والنص، والمشغّل
  المصغّر عند التشغيل فقط», `UD-05`
  «مؤشر في الهامش للآية التي عليها علامة أو ملاحظة» (Mushaf board: «شريط زمردي في الهامش،
  ولونه الداخلي من تصنيف العلامة»), `RD-16` while reading, `NF-05` 200 ms.
- Criterion: «العلامة تُنشأ بلمستين من الآية». A word tap at the medium and study levels
  opens `/sheet/word/:address`, which P1-31 builds in wave 4. The waqf-mark card is blocked (registry row 19): a tap on a
  mark does nothing yet.

## Do

1. Wire P1-22's gesture layer and pinch into the reader: word tap by level (policy of
   P1-04), marker tap and long press select the ayah and show the toolbar, margin tap
   toggles the interface (distraction-free state of P1-14), pinch saves the step.
2. `lib/ui/core/widgets/ayah_toolbar.dart` (PRD §7.7: `IconButton` and `selection`):
   play opens `/sheet/play-options/:address` (P1-28, merged before this task); bookmark
   creates the bookmark at that second tap, in the category the owner chose in
   question 14 of `docs/plans/PHASE1.md` §9 (if he has not answered, the second tap
   opens the four category chips instead, and report it). Study, copy and share are
   added by P1-31 in wave 4, when the ayah sheet and the D-051 icons exist.
3. Margin ribbon for a bookmarked ayah in its category's colour, with a shape (`AX-05`);
   the note indicator needs the note icon: same rule as copy and share.
   It is painted in the reader's margin, in `lib/ui/core/reader/` (yours this wave).
4. Keep-awake while the reader is open and the setting is on (P1-18).
5. Gallery: the toolbar and the ribbon in `mushaf_gallery.dart`.

## Tests

Each tap at each level; two taps make a bookmark; the ribbon appears and goes with
undo; the simple level shows only the position bar and the text; keep-awake follows the
setting. Golden tests of the toolbar and ribbon.

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
- `lib/ui/core/reader/`
- `lib/routing/routes/mushaf_routes.dart`
- `lib/ui/core/widgets/ayah_toolbar.dart`
- `test/ui/core/reader/`
- `test/ui/core/gallery/mushaf_gallery_test.dart`
- `test/guards/allow/contrast/p1-23-*.txt`
- `lib/ui/core/metrics/reader_screen_metrics.dart`
- `lib/ui/core/gallery/sections/mushaf_gallery.dart`
- `test/ui/features/mushaf/`, `test/ui/core/widgets/ayah_toolbar_test.dart`

### Do not touch
`lib/ui/core/widgets/word_sheet.dart`, `lib/ui/core/widgets/ayah_marker.dart` (standalone
markers are checked in P1-35), `lib/data/`, `lib/l10n/`.

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

- `feat(reader): taps, long press, margin and pinch in surah mode (LV-03)`
- `feat(ayah): ayah toolbar with two-tap bookmark (UD-05)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
