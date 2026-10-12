# P1-10 — Address input: go-to and direct-jump parsing (M1.3, M1.8)

Wave 1 · Agent `data-builder` · Key 2 · Cap $15 · Base `main` · Needs: P1-02, P1-03.

## Why

- `NV-03`: «"اذهب إلى": سورة، سورة وآية، صفحة، جزء، حزب أو ربع. يقبل الأرقام المشرقية
  والغربية». Criterion: «كل إدخال صالح ينقل إلى موضعه الصحيح. الإدخال غير الصالح يُرفض
  بجملة تسمّي السبب، مثل «لا توجد آية 300 في البقرة»».
- `SR-07`: «الانتقال المباشر من الحقل: «2:255»، «البقرة 255»، «صفحة 42»».
- Matching typed surah names against the pack's names reads pack strings outside
  display: a new sink under D-114 (`docs/plans/PHASE1.md` §6).

## Do

1. `parse_go_to.dart`: structured input (target kind and numbers) to a `GoToTarget`
   (surah, surah and ayah, page, juz, hizb, rub) or a `GoToError` (no such ayah in a
   surah, no such surah, page, juz, hizb or rub out of range, unreadable), checked
   against P1-02's `QuranStructure`.
2. `parse_direct_jump.dart`: free text to a target or nothing (then it is a search).
   Accepts Western, Arabic-Indic and extended Arabic-Indic digits and the `:` form.
   The words it recognises («صفحة» and the like) are passed in by the caller from the
   ARB file; no Arabic literal in `lib/`.
3. `lib/data/services/surah_name_index.dart`: from `SurahInfo.name`, a lookup from the
   stored name to the surah number. The query arrives already trimmed by
   `parse_direct_jump` (domain); this sink only compares and calls no string-changing
   method (the pack-text guard forbids them in sinks). P1-21
   later decides whether the shared query fold applies; leave a single function to
   swap. Add its sink entry.
4. `AddressInputRepository` (abstract and implementation) offering the name lookup; fill `lib/config/providers/address_providers.dart`; fake
   `testing/fakes/fake_address_input_repository.dart`.

## Tests

Table tests for every form and digit system; every error kind with its data (the
surah and ayah of "no such ayah"); names on a synthetic pack; text that is not a jump
returns nothing.

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
- `lib/domain/models/go_to_target.dart`
- `lib/domain/models/go_to_error.dart`
- `lib/domain/use_cases/parse_go_to.dart`
- `lib/domain/use_cases/parse_direct_jump.dart`
- `lib/data/services/surah_name_index.dart`
- `lib/data/repositories/address_input_repository.dart`
- `lib/config/providers/address_providers.dart`
- `testing/fakes/fake_address_input_repository.dart`
- The tests that mirror these files (same path under test/, ending in _test.dart)
- `test/guards/allow/pack_text/sinks/p1-10-surah-name-index.txt`

### Do not touch
`lib/ui/`, `lib/l10n/`, the repositories of P1-05.

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

- `feat(index): parse go-to input with both digit systems (NV-03)`
- `feat(search): parse direct jumps from the search field (SR-07)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
