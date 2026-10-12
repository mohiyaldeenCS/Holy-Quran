# P1-39 — Approved project icons into the generator (M1.6, M1.9)

Wave: the first of waves 1 to 4 to start after the owner approves P1-11's drawings ·
Agent `content-engineer` · Key 2 · Cap $15 · Base `main` · Needs: the owner's
approval of each icon, recorded by the lead in `docs/plans/icons/README.md` or pasted
below. Never in wave 5 (P1-37 owns `tools/gen/` then).

## Why

D-051: the eight icons are drawn by this project and approved by the owner one by one
before use. D-116 (`docs/plans/PHASE1.md` §6): approved icons live in
`tools/gen/project_icons/` and are generated after the identity's 26. They unblock the
toolbar's copy and share (`SH-01`, `SH-02`), the source badge (`TF-05`), the note
indicator (`UD-05`), delete (`UD-07`) and the player's stop and surah buttons (`AU-05`).

## Do

1. Copy only the approved SVGs from `docs/plans/icons/` to
   `tools/gen/project_icons/<name>.svg`, byte for byte.
2. Extend the generator to append them to `IconName` after the identity's 26, in a
   fixed order, with their names; regenerate `lib/ui/core/widgets/icon_paths.g.dart`.
3. If the gallery's icon section lists `IconName.values`, nothing else changes there;
   otherwise report.
4. An icon not approved stays out; say which.

## Tests

The generator test: the new icons parse, sit after the 26, and the generated file is
current; `test/ui/core/widgets/icon_test.dart` draws each new icon. Golden images of
the icon section change: they are made by the CI `goldens` task.

## Acceptance

- `dart format .` changes nothing, `flutter analyze` reports no issues, and
  `flutter test --exclude-tags golden test tools/gen/test` passes (add `spike` if that
  folder exists). Run all three before the last commit, fix what fails, and run them
  again. Never weaken, skip or delete a test to make it pass.
- Golden images are made only by the CI `goldens` task (D-056). Write new golden tests
  tagged `golden`; never create or commit a `.png` file. A new golden test without its
  image is expected.
- Each acceptance criterion quoted above is reported as met (with its test), partial
  (with the reason) or a pending human check (device, reviewer or owner).

## Self-review

Through the Task tool, run `code-reviewer` on your whole diff. Fix every blocking
and should-fix finding, re-run the checks, and ask again until none remains. Say in
the report which nits you left and why.

## Files

### You own
- `tools/gen/`
- `lib/ui/core/widgets/icon_paths.g.dart`
- `lib/ui/core/widgets/icon.dart` (only if the enum mapping needs it)
- `test/ui/core/widgets/icon_test.dart`

### Do not touch
`design/`, `docs/plans/icons/` (read only), other widgets.

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

`feat(ds): generate the owner-approved project icons (D-051)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
