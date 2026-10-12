# P1-16 — Home frame: header, greeting, continue-reading card, index door (M1.1, M1.2, M1.3)

Wave 2 · Agent `ui-builder` · Key 2 · Cap $15 · Base `main` · Needs: P1-04, P1-05.

## Why

PRD §7.1: home holds «التحية، بطاقة «أكمل القراءة»، «أكمل الاستماع»، الأبواب (الفهرس،
العلامات)»; «الباب في الرئيسية يظهر فقط لميزة صدرت فعلًا». §12.3: two doors until
Phase 2. M1.2 adds the continue-reading card, M1.3 the index door. The M0.5 review
left the greeting strings and the header padding to this milestone (D-091, item 4).
The card's gold label is below 4.5:1 (O-12): keep the identity's value and list it.

## Do

1. `HomeViewModel` over the reading position (P1-04) and the index (P1-05).
2. `HomeScreen` as the Screens board draws it, without the Phase 2 parts: `HomeHeader`
   with «السلام عليكم» and «أكمل من حيث توقفت»; the search entry to `/study/search`;
   `ContinueCard` with the surah name (`SurahName`), «الآية {ayah} · صفحة {page} ·
   الجزء {juz}», the progress through the mushaf (page over the pack's page count) and
   «تابع القراءة» to `/mushaf/read/<address>`; hidden when there is no position yet;
   the index door to `/mushaf/index`. The bookmarks door and «أكمل الاستماع» come in
   P1-26, when their features exist.
3. Header padding and card spacing from the board into
   `lib/ui/core/metrics/home_metrics.dart`, each citing its source.
4. `lib/routing/routes/home_routes.dart`.

## Tests

First run without a position shows no card; with one, the card's line and target;
the door opens the index route; four themes and 200% without overflow; golden tests
of the home screen.

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
- `lib/ui/core/metrics/home_metrics.dart`
- `lib/routing/routes/home_routes.dart`
- `test/ui/features/home/`

### Do not touch
`lib/ui/core/widgets/`, `lib/l10n/`, `lib/data/`, `lib/main.dart`.

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

`feat(home): home frame with greeting, continue-reading card and index door (M1.2)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
