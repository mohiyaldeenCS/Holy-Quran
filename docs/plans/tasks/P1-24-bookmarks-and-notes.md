# P1-24 — Bookmarks and notes screens (M1.6)

Wave 3 · Agent `ui-builder` · Key 2 · Cap $30 · Base `main` · Needs: P1-05, P1-17, P1-18.

## Why

`UD-01` (the four categories of `Tag`; «تفسير» and user-made categories wait for
O-14), `UD-02` free tags, `UD-03` «قائمة العلامات: ترتيب بالأحدث أو بترتيب المصحف، تصفية
بالتصنيف والوسم، وبحث», `UD-04` notes, several per ayah, `UD-07` «الحذف مع مهلة تراجع»,
`SR-08` «البحث في العلامات والملاحظات». PRD §7.5: «لا توجد علامات بعد». PRD §7.7: the
note editor «نص، تصنيف، وسوم» from `Tag` and `Button`. These screens are extensions
(PRD §7.6): follow the nearest drawn screen (`docs/DESIGN_SYSTEM.md`).

## Do

1. Bookmarks screen (`/more/bookmarks`): ayah cards (`AyahRow`) with category and tags,
   order newest or mushaf («ترتيب المصحف» exists; «الأحدث» is Appendix B), filter by
   category and tag, search over notes and tags (P1-18), the empty state «لا توجد
   علامات بعد».
2. Note editor (`/sheet/note/:address`): body, category, tags; several notes per ayah.
   Its labels are in Appendix C: build only what has keys, and report.
3. Delete with an undo action «تراجع». The delete control is an icon of D-051: add it
   only if `IconName` has it (P1-39); otherwise report.
4. Each card opens the reader at its ayah, or the context sheet.
5. Gallery: the note editor in `controls_gallery.dart`; new colour pairs as entries
   under `test/guards/allow/contrast/`.
6. `lib/routing/routes/bookmarks_routes.dart`; metrics in `bookmarks_metrics.dart`.

## Tests

Order, filter and search; several notes on an ayah; undo restores; the empty state;
nothing lost on a level change; four themes and 200%. Golden tests.

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
- `lib/ui/features/bookmarks/`
- `lib/ui/core/widgets/note_editor.dart`
- `lib/routing/routes/bookmarks_routes.dart`
- `lib/ui/core/metrics/bookmarks_metrics.dart`
- `lib/ui/core/gallery/sections/controls_gallery.dart`, `test/ui/core/gallery/controls_gallery_test.dart`
- `test/guards/allow/contrast/p1-24-*.txt`
- `test/ui/features/bookmarks/`, `test/ui/core/widgets/note_editor_test.dart`

### Do not touch
`lib/data/`, `lib/l10n/`, other features.

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

- `feat(bookmarks): bookmark list with order, filter and search (UD-03)`
- `feat(bookmarks): notes on an ayah with tags (UD-04)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
