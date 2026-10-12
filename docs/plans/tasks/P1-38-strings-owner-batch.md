# P1-38 — Strings, second batch, from the owner's answers (Phase 1)

Wave: the first of waves 1 to 5 to start after the owner answers questions 1 and 2
of `docs/plans/PHASE1.md` §9 (never beside P1-01) · Agent `ui-builder` · Key 1 · Cap $8 · Base `main` ·
Needs: the owner's answers, pasted by the lead below the line at the end of this text.

## Why

Many Phase 1 screens leave elements out because their wording is in Appendix B
(phrases from the PRD awaiting approval) or Appendix C (no wording anywhere) of
`docs/plans/PHASE1.md` §8. No task invents Arabic wording (D-115). Once the owner has
approved B and given C, this task adds them, so the owning screens can be completed.

## Do

1. Add to `lib/l10n/app_ar.arb` exactly the wording the lead pasted below, each with a
   description naming "owner, <date>" or the PRD passage. Copy the characters; never
   retype or adjust them. Placeholders that carry numbers are `String`s.
2. Plurals the owner gave are ICU plurals with every form he wrote; a missing form is
   reported, never filled in.
3. Regenerate the localisation files and commit them.
4. List, per key, the task and screen that waits for it (from §8 and the reports).

## Tests

`test/l10n/phase1_strings_second_batch_test.dart`: every pasted key exists with its
description; no Western digit, exclamation mark or emoji.

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
- `lib/l10n/app_ar.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_ar.dart`
- `test/l10n/phase1_strings_second_batch_test.dart`

### Do not touch
Everything else.

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

`feat(l10n): add the owner-approved Phase 1 strings (Phase 1)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.

---

Owner-approved wording (pasted by the lead when starting the run):
