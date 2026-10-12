# P1-34 — Critical-path flow tests (M1.11)

Wave 4 · Agent `test-engineer` · Key 2 · Cap $30 · Base `main` · Needs: waves 1 to 3
merged.

## Why

`NF-20` «اختبارات آلية للمسارات الحرجة: مطابقة النص، خطة التشغيل، حساب الورد، الدمج في
المزامنة | تُشغَّل مع كل تغيير، وفشلها يمنع الإصدار» (Phase 1 has the first two).
`docs/ARCHITECTURE.md`, "Testing": open the last position; search and open a result;
play a range; bookmark; download, verify and activate a pack. Criteria: «حذف حزمة ثم
إعادة تنزيلها يعيد العلامات والملاحظات المرتبطة بها كما كانت»; «العلامة تُنشأ بلمستين من
الآية»; «النص المنسوخ ... يطابق نص الحزمة. اختبار آلي على الآيات كلها للنسخ».

## Do

1. `test/flows/`: whole-app widget tests that run in CI with synthetic packs, fakes
   for plugins and a local HTTP server: start-up to the last position; search and
   open a result; play a range (fake engine) with repeat 3 heard exactly three times;
   bookmark an ayah in two taps; download, verify, activate, delete and download a
   pack again with bookmarks and notes unchanged; copy text equals the pack for every
   ayah (and for a real pack given with `HOLYQURAN_PACK_DIR`).
2. `integration_test/`: the same flows for a device, with real plugins, listed as
   pending device runs.
3. Shared helpers in `testing/flows/`.
4. A failure found in another task's code is reported with its reproduction, not
   fixed outside your files.

## Tests

As above; all of `test/flows/` passes in the acceptance command.

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
- `test/flows/`
- `integration_test/`
- `testing/flows/`

### Do not touch
`lib/`, other tests.

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

- `test(flows): critical paths with synthetic packs (NF-20)`
- `test(flows): device integration tests for the critical paths (NF-20)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
