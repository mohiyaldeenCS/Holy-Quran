# P1-33 — Recitation downloads and quality (M1.9)

Wave 4 · Agent `ui-builder` · Key 1 · Cap $25 · Base `main` · Needs: P1-25, P1-27.

## Why

`AU-13` «التنزيل: سورة، جزء، أو المصحف كاملًا لتلاوة. يُعرض الحجم قبل البدء، ويُستأنف بعد
الانقطاع، مع خيار Wi-Fi فقط»; `AU-14` «اختيار الجودة حين يتوفر أكثر من مستوى». Criterion:
«التنزيل يُستأنف دون إعادة ما اكتمل، وكل ملف يُتحقق ببصمته قبل اعتماده». Real
recitations wait for the recitations the planning session proposes and the owner
approves (O-04, D-119), B0.5 and complete rights records: synthetic catalogue only.

## Do

1. The recitations section of the resource manager
   (`lib/ui/features/resources/views/sections/recitation_section.dart`): per
   recitation, download a surah, a juz or the whole, with its size from the recitation
   pack before starting; progress, stop, resume, delete; Wi-Fi only.
2. Quality choice when the catalogue offers more than one.
3. The picker of P1-27 shows each recitation's download state (in
   `lib/ui/features/listen/`, yours this wave); playback prefers local files (already
   in P1-13's repository).
4. Labels missing from the ARB (size notice, Wi-Fi only, quality) are left out and
   reported.

## Tests

Size shown before start; jobs queued per surah and juz; resume and verification by the
installer (fakes); quality choice; state in the picker. Golden tests of the section.

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
- `lib/ui/features/resources/`
- `lib/ui/features/listen/`
- `lib/routing/routes/resources_routes.dart`
- `lib/ui/core/metrics/resources_metrics.dart`
- `test/ui/features/resources/`, `test/ui/features/listen/`

### Do not touch
`lib/data/`, `lib/l10n/`, `lib/ui/core/tab_shell.dart`, `lib/ui/core/widgets/`.

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

- `feat(audio): download recitations by surah, juz or whole (AU-13)`
- `feat(audio): choose the recitation quality (AU-14)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
