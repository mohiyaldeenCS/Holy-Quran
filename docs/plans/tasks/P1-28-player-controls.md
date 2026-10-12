# P1-28 — Player sheets: range, play options, repeat, silence, stop-after, sleep, queue (M1.9)

Wave 3 · Agent `ui-builder` · Key 2 · Cap $30 · Base `main` · Needs: P1-19.

## Why

`AU-02` ranges; `AU-03` «من أدوات الآية: الآية فقط، حتى نهاية الصفحة، حتى نهاية السورة،
حتى نهاية الجزء، حتى أوقفه»; `AU-07` sleep timer; `AU-08` stop-after; `AU-09` «التكرار:
آية، نطاق، صفحة، سورة. العدد من 1 إلى 99 أو بلا نهاية»; `AU-11` «صمت بين الآيات من 0 إلى
30 ثانية»; `AU-17` «قائمة الانتظار: إضافة وترتيب وحذف». PRD §7.7: «محدد النطاق | من آية إلى
آية، أو صفحة، أو جزء، أو حزب | `Stepper` و`ModeChips`». Criterion: «التكرار بعدد n يُسمِع n
مرات بالضبط، والعدّاد ظاهر ومنطوق لقارئ الشاشة».

## Do

Sheets as modal routes in `lib/routing/routes/listen_controls_routes.dart`, views and
view models under `controls/`, each building a plan with P1-08 and handing it to
P1-19's `PlayerRepository`:

1. `/sheet/range`: from ayah to ayah, page, juz or hizb (`ModeChips`, `Stepper`).
2. `/sheet/play-options/:address`: the five options of `AU-03` (ARB keys exist).
3. `/sheet/repeat`: 1–99 (`Stepper`) and unlimited (Appendix B).
4. `/sheet/silence`: 0–30 s, «صمت {seconds} ث».
5. `/sheet/stop-after` and `/sheet/sleep`: their labels are Appendix B and C; build
   what has keys and report the rest.
6. `/sheet/queue`: the queue with reorder and remove; "add to queue" words are
   Appendix C (D-052).
7. The repeat counter is visible and announced to the screen reader.

## Tests

Each sheet builds the plan it should (fake player); bounds of each stepper; queue
order changes; the counter's semantics. Golden tests of each sheet.

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
- `lib/ui/features/listen/views/controls/`
- `lib/ui/features/listen/view_models/controls/`
- `lib/routing/routes/listen_controls_routes.dart`
- `lib/ui/core/metrics/player_controls_metrics.dart`
- `test/ui/features/listen/controls/`

### Do not touch
P1-27's player files, `lib/ui/core/tab_shell.dart`, `lib/data/`, `lib/domain/`, `lib/l10n/`.

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

- `feat(audio): range and play-option sheets (AU-02)`
- `feat(audio): repeat, silence, stop-after, sleep and queue sheets (AU-09)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
