# P1-14 — Reader screen in surah mode (M1.2)

Wave 2 · Agent `ui-builder` · Key 2 · Cap $30 · Base `main` · Needs: P1-04, P1-05,
P1-09.

## Why

- `RD-01` (from the bundled pack, offline), `RD-02` (surah mode), `RD-05` «شريط
  الموضع في الوضعين: السورة، الجزء، الحزب، رقم الصفحة المرجعي» (surah mode now),
  `RD-06`, `RD-09` «وضع بلا تشتيت يخفي كل عناصر الواجهة ويُبقي النص», `RD-10`
  (portrait and landscape), `RD-11` «تمرير عمودي متصل في وضع السورة», `RD-12` «حفظ آخر
  موضع قراءة تلقائيًا: أول آية ظاهرة عند توقف التمرير أو مغادرة القارئ», `RD-15`,
  `RD-17` «سطر معلومات تحت رأس السورة (مكية أو مدنية، عدد الآيات، الترتيب) يفتح مقدمة
  السورة» (Phase 1: the basic facts only), `NV-06` (every address a route inside the
  app).
- Criteria: byte-exact text for every ayah; «مع تكبير النظام 200% لا اقتطاع ولا تداخل
  في وضع السورة»; «القراءة والفهارس تعمل دون اتصال من أول تشغيل».
- PRD §9.5: while the base pack fails its check, no text from it is shown.

The reader is drawn on the Screens board (reader) and the Mushaf board (position bar,
surah header, info line, «مقدمة السورة»).

## Plan first

Ask `flutter-architect` for the view model and screen plan over P1-09's engine.

## Do

1. `ReaderViewModel` holds addresses and state (the layout itself, which needs
   `TextPainter`, stays in the view through P1-09's engine): it opens at the route's
   address or the last position, continues into the next surah as the user scrolls,
   tracks the first visible ayah, and saves it on scroll end and on leaving (D-106).
2. `ReaderScreen` replaces the placeholder of the mushaf tab: the position bar (surah,
   juz, hizb, page) as a new widget `lib/ui/core/widgets/position_bar.dart` from the
   Mushaf board; the surah header (`SurahHeader` gains a tappable info line with a 48
   hit area and a label) with its info line, which
   opens `/sheet/surah-info/:surah` titled «مقدمة السورة» with the same facts; the
   basmala and margin marks from the engine; a distraction-free state that hides
   everything but the text, the tab bar too, through P1-02's `ShellChrome` (the
   gesture that toggles it is P1-23's).
3. Landscape reflows with no clipping.
4. While the base pack's integrity is failed or missing, show no pack text. The alert's
   wording does not exist yet (Appendix C): show nothing more, and report.
5. `lib/routing/routes/mushaf_routes.dart`: `/mushaf`, `/mushaf/read/:address`, the
   surah-info sheet. Metrics in `lib/ui/core/metrics/reader_screen_metrics.dart`.

## Tests

Over synthetic packs and fakes: the screen shows every ayah of a surah byte for byte
(`test/integrity/reader_text_integrity_test.dart`); opening at an address; the
position bar follows scrolling; the position is saved on scroll end and on leaving;
continuing into the next surah; surah 9 without basmala; 200% and landscape without
overflow; nothing shown while the base pack is failed. Golden tests of the reader in
four themes.

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
- `lib/ui/core/metrics/reader_screen_metrics.dart`
- `lib/ui/core/widgets/position_bar.dart`, `lib/ui/core/widgets/surah_header.dart`
- `test/ui/core/widgets/position_bar_test.dart`, `test/ui/core/widgets/surah_header_test.dart`
- `lib/routing/routes/mushaf_routes.dart`
- `test/ui/features/mushaf/`
- `test/integrity/reader_text_integrity_test.dart`
- `test/routing/mushaf_routes_test.dart`

### Do not touch
`lib/ui/core/reader/` (P1-22 owns it in this wave; report a needed change), the
other widgets, `lib/data/`, `lib/l10n/`.

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

- `feat(reader): surah-mode reader with position bar and info line (RD-02)`
- `feat(reader): save and restore the reading position (RD-12)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
