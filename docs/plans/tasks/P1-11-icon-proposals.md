# P1-11 — Draw the eight icons of D-051 as proposals for the owner (M1.6, M1.9)

Wave 1 · Agent `ui-builder` · Key 1 · Cap $12 · Base `main` · Needs: the lead's step 0.

## Why

D-051: the icons Phase 1 needs that the identity lacks — copy, share, information,
note, delete, stop, next surah, previous surah (eight drawings, D-059) — are drawn by
this project on the identity's icon rules and approved by the owner one by one before
use. They gate the ayah toolbar's copy and share (`SH-01`, `SH-02`), the source badge
(`TF-05`, `LX-11`), the note and its margin indicator (`UD-04`, `UD-05`), delete
(`UD-07`) and the full player's stop and surah buttons (`AU-05`). The list and its
needs are in `docs/DESIGN_SYSTEM.md`, "Icons Phase 1 needs".

## Do

1. Read the icon rules: `design/design-system/README.md`, the `Icon` component and
   the `ICONS` map in `design/design-system/components/src/index.jsx`, and how
   `tools/gen/` reads them (which SVG path commands it accepts).
2. Draw each icon as an SVG on the identity's grid, stroke, caps and joins, echoing
   the nearest identity icon (for example next and previous surah built from `next`
   and `previous`). Only path commands the generator accepts.
3. Write `docs/plans/icons/<name>.svg` (eight files) and
   `docs/plans/icons/README.md`: per icon, the need it serves, how it follows each
   rule, the identity icon it echoes, and a line for the owner's decision.
4. `docs/plans/icons/preview.html`: the eight beside the identity's 26 at 24 and 48
   px on the `paper` and `night` grounds (colours copied from `tokens.css`), plain
   HTML and inline SVG; no PNG.
5. Change no app code: the approved icons enter the generator in P1-39.

## Tests

`tools/gen/test/project_icon_proposals_test.dart`: each proposal parses with the
generator's own path parser, fits the grid and uses only allowed commands.

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
- `docs/plans/icons/` (handed over for this task)
- `tools/gen/test/project_icon_proposals_test.dart`

### Do not touch
`design/` (nobody changes it), `tools/gen/lib/` and `bin/`, `lib/`.

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

`docs(design): propose the eight Phase 1 icons of D-051 (Phase 1)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
