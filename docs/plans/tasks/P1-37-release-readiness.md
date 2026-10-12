# P1-37 — Release readiness: launcher icon, launch screen, privacy guard (M1.11)

Wave 5 · Agent `ui-builder` · Key 1 · Cap $25 · Base `main` · Needs: wave 4 merged.

## Why

M1.11: launcher icon and native launch screen; store compliance (PRD §11.1: in-app
account deletion only with accounts, declared privacy data, local mushaf approvals
per market). `NF-06` base download size (60 MB target; measured by the lead with the
CI `apk` task, never beside a test run); `NF-10` Android 8.0 (D-070), the iOS target
set when iOS builds start (D-042); `NF-14` «سجل القراءة والملاحظات بيانات تدل على المعتقد،
فتُعامل بيانات حساسة | لا تُرسل لطرف ثالث. التحليلات بموافقة ومجهولة»; D-001: no ad,
purchase or tracking SDK. Read D-117 (`docs/plans/PHASE1.md` §6).

## Do

1. Android adaptive launcher icon and launch screen as vector drawables built from the
   logo SVGs in `design/design-system/assets/Logos/` (hashes in `design/README.md`); no
   PNG. Colours for native files come from the tokens: extend `tools/gen/` to write
   `android/app/src/main/res/values/brand_colors.xml`, regenerated and checked like
   the other generated files.
2. `test/guards/privacy_test.dart`: `pubspec.yaml` lists no analytics, crash, ad,
   purchase or tracking package; in `lib/`, only the catalogue, download and audio
   streaming services and the link service make network calls or open links; no user-database type reaches them.
3. The store-compliance checklist and the iOS items owed (icons, launch screen,
   deployment target) in the report.

## Tests

The generator's output is current; the privacy guard passes and fails on an injected
violation.

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
- `android/app/src/main/res/` (handed over)
- `android/app/src/main/AndroidManifest.xml` (icon and label attributes only; handed over)
- `tools/gen/` (handed over for this wave)
- `test/guards/privacy_test.dart`
- `tools/gen/test/` for the new output

### Do not touch
`lib/`, `pubspec.*`, `ios/` (iOS waits for D-042), `.github/`.

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

- `build(android): launcher icon and launch screen from the logo (M1.11)`
- `test(guards): no network path carries user data (NF-14)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
