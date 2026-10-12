# P1-20 — Tafsir repository (M1.7)

Wave 2 · Agent `data-builder` · Key 2 · Cap $20 · Base `main` · Needs: P1-04, P1-05, P1-06,
P1-07.

## Why

`TF-02` and `TF-03` «التنقل آية آية داخل التفسير مع بقاء الآية ظاهرة أعلاه»; `TF-04`
«التفسير الذي يشرح عدة آيات معًا يُعرض مقطعه مرة واحدة مع بيان نطاقه»; `TF-05` badge
fields; `TF-08` quoted ayat stay source text; criterion «لكل آية من الآيات كلها مقطع في
كل تفسير منزَّل أو بيان «لا يوجد تفسير لهذه الآية في هذا الكتاب»». Real tafsirs wait for
O-06, B0.7 and their rights records (rows 9 and 10 are `Ready`, row 8 is `Verify`,
Zaydi-library books wait for O-07): this task works on synthetic tafsir packs.

## Do

1. `TafsirRepository` (abstract and implementation): installed tafsir packs (from
   P1-07's installed list), the book facts for the badge, the passage for an ayah
   (with its range) or none, navigation to the next and previous ayah that shows a
   ranged passage once, and the default tafsir as a setting key the repository owns
   (through the settings store).
2. Each tafsir pack is verified once per session through P1-05's
   `PackIntegrityRepository`; a failed pack serves nothing and its state is exposed
   for the resource manager's alert.
3. Passage text travels as `PackText`, untouched; quoted ayat inside it are part of
   the source's text and get no special treatment.
4. Fill `lib/config/providers/tafsir_providers.dart`; fake
   `testing/fakes/fake_tafsir_repository.dart`.

## Tests

Every ayah of the synthetic pack has a passage or "none"; a ranged passage returned
once across its ayat; navigation at the edges of a surah and of the Quran; passage
bytes equal the pack's; the default tafsir persists.

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
- `lib/data/repositories/tafsir_repository.dart`
- `lib/domain/models/tafsir_position.dart`
- `lib/config/providers/tafsir_providers.dart`
- `testing/fakes/fake_tafsir_repository.dart`
- The tests that mirror these files (same path under test/, ending in _test.dart)
- `test/guards/allow/pack_text/carriers/p1-20-tafsir.txt`

### Do not touch
P1-06 and P1-07's files, `lib/ui/`.

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

`feat(tafsir): read passages, ranges and navigation from tafsir packs (TF-04)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
