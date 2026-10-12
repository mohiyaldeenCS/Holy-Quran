# P1-03 — Keep the guards' allow-lists as one file per entry (Phase 1)

Wave 0 · Agent `test-engineer` · Key 1 · Cap $8 · Base `main` · Needs: the lead's
step 0 merged.

## Why

The guards in `test/guards/` keep Quran text untouched on its way to the screen
(D-062, D-084; PRD §9.1, §9.4) and keep the layers apart (`docs/ARCHITECTURE.md`,
"Import rules"). Their allow-lists are constants inside the test files, so every task
that adds a sink, a pack-text producer or a database importer would edit the same
file, and parallel tasks would collide. D-114 (proposed in `docs/plans/PHASE1.md` §6)
moves each list into a folder with one file per entry, without weakening any guard.

## Do

1. Read every file in `test/guards/`. In `pack_text_guard_test.dart` move `_sinks`,
   `_producers`, `_verifiers` and the carrier rule (today a pattern for
   `lib/data/repositories/*quran_text*.dart`) into
   `test/guards/allow/pack_text/{sinks,producers,verifiers,carriers}/`. In
   `import_rules_test.dart` move `_nonPlugins` (packages any layer may import) and
   `_rampImporters` into `test/guards/allow/imports/{non_plugins,ramps}/`;
   `_databasePackages` is a deny list for `lib/ui` and stays. In `contrast_test.dart`
   move the colour pairs, thresholds and known exceptions into
   `test/guards/allow/contrast/`, one pair per entry, so that each UI task adds its own
   pairs. Leave other guards as they are
   unless they hold a path list that Phase 1 tasks must extend; say which in the
   report.
2. Entry format, one small text file per entry, named `<task>-<what>.txt` (existing
   entries `m0-<what>.txt`): line 1 the path, or a folder ending in `/` that covers
   the files under it; line 2 `decision: D-xxx`; line 3 optional, one sentence why.
   Write `test/guards/allow/README.md` with the format and the rule that adding an
   entry is a reviewed change.
3. `test/guards/allow_list.dart` loads a folder and fails with a precise message on a
   malformed entry, a path that does not exist (folders excepted when empty), or a
   path listed twice.
4. Prove that nothing got weaker: the set of allowed paths equals the old constants
   (write the old sets into the test once, as the expected value of the migration);
   each guard still fails on an injected violation (the existing in-memory source
   tests); the whole suite passes.

## Tests

As above, in `test/guards/allow_list_test.dart` and the updated guard tests.

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
- `test/guards/` (every file in it, the new `allow/` folder and `allow_list.dart`)

### Do not touch
`lib/`, `testing/`, `test/integrity/`, `pubspec.*`.

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

`test(guards): keep allow-lists as one file per entry (Phase 1)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
