# P1-09 — Surah-mode layout engine, ported from spike S1 (M1.2)

Wave 1 · Agent `ui-builder` · Key 1 · Cap $30 · Base `main` · Needs: P1-03 (and
P1-01 for the margin labels; without it, leave the labels out and report).

## Why

- `RD-02`: «وضع السورة: نص متدفق، رأس سورة، بسملة سطرًا مستقلًا عدا التوبة (وفي الفاتحة
  آية مرقّمة)، فواصل آيات، وعلامات الهامش للربع والحزب والجزء والسجدة والعلامة المرجعية».
- `RD-06`: «في وضع السورة تظهر علامة عند حدّ كل صفحة مرجعية مع رقمها» (inside the line,
  D-071). `RD-07`: «درجات من 80% إلى 200%». `RD-15`: «علامتها من النص وكلمة «سجدة» في
  الهامش». `WQ-01`: «علامات الوقف تظهر كما هي في النص، ولا تُحذف لتوفير المساحة».
- Criteria: «كل آية معروضة في أي وضع تطابق نص الحزمة المعتمدة بايتًا ببايت»; «مع تكبير
  النظام 200% لا اقتطاع ولا تداخل في وضع السورة». `NF-02`: 60 fps.
- Carried findings: S1 (`docs/spikes/S1-surah-rendering.md`): inline placeholders
  reordered on right-to-left lines; ink leaves its line band, so recolour, never clip;
  a word shapes by the word before it, so no line is laid out alone; a pause mark can
  start a line cut off from its word, which must be prevented without changing any
  character; blocks of ayat must break exactly as one block would. M0.2: the last
  line of page-size text is centred. M0.5: a word wider than its line must stay whole.
  Read D-060, D-071, D-091 and D-113 (`docs/plans/PHASE1.md` §6).

## Plan first

Ask `flutter-architect` for the file plan. Read the spike code at the commit the S1
page cites (`git show <sha>:spike/s1/render/…`; if missing, work from the page).

## Do

In `lib/ui/core/reader/`:

1. A paragraph builder that turns an ayah's `PackText` and its stored word and mark
   spans into spans and ayah-marker placeholders (a pack-text sink: add its entry in
   `test/guards/allow/pack_text/sinks/`, citing D-113).
2. Line breaking at stored word boundaries only, so that a word and the marks that
   follow it are never split across lines, with no character added, replaced or
   removed; justified lines, the last line of a block centred; a word wider than the
   line kept whole (as `WordSheet` does, D-091 item 12).
3. Blocks of ayat for long surahs whose line breaks equal a single-block layout
   (S1's V2), laid out lazily in a sliver list; the first visible ayah and jumping to
   an address, for saving and restoring the position.
4. The basmala as its own line from the pack's basmala field, none for surah 9, ayah 1
   in surah 1; page-boundary marks inside the line from the page divisions (D-071);
   margin marks for rub, hizb, juz and sajda with the ARB labels «ربع»، «الحزب {n}»،
   «الجزء {n}»، «سجدة».
5. The text-size ladder from 80% to 200% (S7's provisional steps 0.8, 0.9, 1.0, 1.15,
   1.3, 1.5, 1.75, 2.0), composed with the system text scale.
6. Expose the laid-out lines and boxes P1-22 needs for targets and highlights; add no
   highlight or gesture code here.
7. Metrics from the boards in `lib/ui/core/metrics/reader_metrics.dart`, each citing
   its source.

## Tests

On synthetic packs with marks (`testing/packs/`): every ayah's spans rejoin to the
pack bytes; no line starts with a mark cut from its word; blocks equal one block in
line starts; last line centred; 200% reflows with no overflow; page marks at the right
places; basmala rules; ladder steps. Golden tests of a block in the four themes,
tagged `golden` (images by CI).

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
- `lib/ui/core/reader/`
- `lib/ui/core/metrics/reader_metrics.dart`
- `test/ui/core/reader/`
- `test/guards/allow/pack_text/sinks/p1-09-reader-paragraph.txt`

### Do not touch
`lib/ui/core/widgets/quran_text.dart` and the other widgets (report a needed change),
`lib/data/`, `lib/l10n/`.

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

- `feat(reader): lay out surah-mode blocks at stored word boundaries (RD-02)`
- `feat(reader): page-boundary and margin marks in surah mode (RD-06)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
