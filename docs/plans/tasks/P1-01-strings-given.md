# P1-01 — Add the Phase 1 strings whose wording is given (Phase 1)

Wave 0 · Agent `ui-builder` · Key 1 · Cap $8 · Base `main` · Needs: the lead's step 0
(`docs/plans/PHASE1.md` §3) merged.

## Why

Every Phase 1 screen needs UI strings, and `lib/l10n/app_ar.arb` is shared by every
task. So one small task adds, before the others start, every string whose exact
wording the PRD or the identity already gives. No task may invent Arabic wording
(`CLAUDE.md`; D-115 proposed in `docs/plans/PHASE1.md` §6). `NF-18`: «واجهة عربية فقط
من اليمين إلى اليسار، وأرقام مشرقية».

## Do

1. Read `docs/plans/PHASE1.md` §8. Add every entry of Appendix A to
   `lib/l10n/app_ar.arb`, each with an `@key` whose `description` names its source
   (board file or PRD section). Key names may change to fit the file's naming; the
   wording never does.
2. Do not retype Arabic. For each wording, find it in its source (the board HTML in
   `design/identity-boards/`, a component in `design/design-system/components/`, or
   `docs/prd/PRD.ar.md`) with a script and copy the characters from there, then
   compare them with the appendix byte for byte. If the appendix and the source
   differ, the source wins; report the difference.
3. Placeholders that carry numbers are `String`s: numbers reach a message already
   formatted by the shared Arabic-Indic digits helper (`docs/ARCHITECTURE.md`,
   "Theming, language, accessibility"). Follow the existing entries (`ayahCount`,
   `wordSheetPosition`).
4. Do not duplicate an existing key with the same meaning (for example
   `resourceDownloaded`, `resourceDelete`, `searchResultOpen`, `searchResultContext`,
   `surahListLastRead`, `searchSortMushafOrder`, `playerSleepTimer`); list in the
   report which appendix entries you mapped to existing keys.
5. Appendix B: add it only if the text you were started with says the owner approved
   it, using the approved wording. Otherwise leave it to P1-38.
6. Regenerate the localisation files with `flutter gen-l10n` (the configuration in
   `l10n.yaml`) and commit them; CI checks that they are current (D-043).

## Tests

`test/l10n/phase1_strings_test.dart`: every key you added exists in the generated
class and has a description naming a source; no message contains a Western digit, an
exclamation mark or an emoji; every placeholder that carries a number is typed
`String`.

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
- `test/l10n/phase1_strings_test.dart`

### Do not touch
Everything else, in particular `lib/ui/`, `l10n.yaml` and `pubspec.*`.

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

`feat(l10n): add the Phase 1 strings with given wording (Phase 1)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
