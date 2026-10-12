# P1-36 — Performance budgets: harness and device protocol (M1.11)

Wave 5 · Agent `test-engineer` · Key 2 · Cap $25 · Base `main` · Needs: wave 4 merged.

## Why

`NF-01` «من فتح التطبيق إلى ظهور آخر موضع قراءة، تشغيلًا باردًا | ثانيتان»; `NF-02` «60 إطارًا
في الثانية، و99% من الإطارات دون 32 مللي ثانية»; `NF-03` «300 مللي ثانية» for offline
search; `NF-05` «فتح ورقة الكلمة أو الآية | 200 مللي ثانية». PRD §11: measured on two
reference devices (a mid-range Android phone with 4 GB, the oldest iPhone on the
minimum iOS). Spike S1 measured cold start and scroll on a spike build; this is the
app's own harness.

## Do

1. `integration_test/perf/`: cold start to the last position (timeline marks from
   process start to the first frame showing the saved ayah), scrolling the longest
   surah at 1500 px/s in surah mode, an offline search, opening the word and ayah
   sheets; each reports numbers as JSON, never text.
2. `test_driver/perf_driver.dart` to collect the timelines in profile mode.
3. The device protocol in the report: steps, phone details to record, what to send.
4. Runs on the reference devices are pending human checks; run what can run on the
   CI runner and report the numbers as informative only.

## Tests

The harness compiles and its parsing of timelines is unit-tested with recorded
samples.

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
- `integration_test/perf/`
- `test_driver/`
- `test/perf/` (unit tests of the harness)

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

`test(perf): budgets harness for start-up, scroll, search and sheets (NF-01)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
