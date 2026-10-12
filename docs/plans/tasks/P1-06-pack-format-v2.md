# P1-06 — Pack format v2: search forms, tafsir kind, recitation kind (M1.4, M1.7, M1.8, M1.9)

Wave 1 · Agent `data-builder` · Key 2 · Cap $30 · Base `main` · Needs: P1-03.

## Why

- `SR-03`: «المطابقة تجري على صيغة إملائية للنص مأخوذة من المصدر نفسه، مربوطة كلمةً
  بكلمة بالنص العثماني». Format v1 has no table for those forms.
- `TF-04`: «التفسير الذي يشرح عدة آيات معًا يُعرض مقطعه مرة واحدة مع بيان نطاقه»;
  `TF-05`: «اسم التفسير، المؤلف، الطبعة أو المحقق، مصدر الرقمنة، الإصدار».
- `AU-13`, `AU-14`: files by surah or ayah, per quality, sizes shown before download,
  each file verified by its hash.
- The format is stream A's to write (D-035, D-064); the pipeline follows it. Read
  `docs/CONTENT_PACKS.md` whole and D-110 in `docs/plans/PHASE1.md` §6.

## Plan first

Ask `flutter-architect` for the v2 schema and the parser changes before writing.

## Do

1. `docs/CONTENT_PACKS.md` (handed over for this task): add "Format version 2".
   - Text pack: a `search_form` table, one row per word of the word index and per
     form kind the source provides (surah, ayah, word, kind, form as the source gives
     it), filled by the
     pipeline from B0.2 and B0.4; the app derives no form of its own (D-037).
   - Kind `tafsir`: `tafsir.sqlite` with the book's facts (title, author, edition or
     editor, digitisation source, version) and passages (id, first and last ayah,
     text verbatim). An ayah without a passage simply has none.
   - Kind `recitation`: `recitation.sqlite` with the recitation (reciter, riwaya,
     style, unit `ayah` or `surah`) and its files (quality, surah, ayah or null,
     relative URL, bytes, SHA-256, duration in ms). Timing waits for registry row 6.
   - Version rules: v1 text packs stay readable; counts per kind; unknown fields
     rejected as in v1.
2. Manifest parser and model: kinds `tafsir` and `recitation`, `format_version` 2.
3. Readers, read-only and immutable (D-061): text v2 in `pack_database.dart`;
   `tafsir_pack_database.dart`; `recitation_pack_index.dart`. Every pack string
   reaches the app as `PackText`. Add producer entries for the new readers.
4. `testing/packs/`: synthetic builders for text v2 with synthetic forms («نص تجريبي»),
   tafsir (a passage over several ayat, an ayah with none) and recitation (two
   qualities, files per ayah and per surah).
5. `test/integrity/` (handed over): v2 checks — exactly one search form per word per kind, tafsir
   ranges valid and in order, recitation files listed with size and hash.
6. Keep the APIs P1-05 calls this wave (`PackManifest`, `PackDatabase`) source
   compatible: add, do not rename or remove.
7. Changes to `docs/CONTENT_PACKS.md` need the planning session's review (D-077):
   say so in the report.
8. If verifying a new kind needs `local_pack_repository.dart` (P1-05's this wave),
   do not edit it: report what must change.

## Tests

Parser accepts v2 and rejects malformed kinds; readers return synthetic content
unchanged byte for byte; the integrity suite runs on the new synthetic packs; v1
packs still open.

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
- `docs/CONTENT_PACKS.md` (handed over)
- `lib/data/models/pack_manifest_json.dart`
- `lib/domain/models/pack_manifest.dart`
- `lib/data/services/pack_database.dart`
- `lib/data/services/tafsir_pack_database.dart`
- `lib/data/services/recitation_pack_index.dart`
- `lib/domain/models/search_form.dart`
- `lib/domain/models/tafsir_passage.dart`
- `lib/domain/models/tafsir_book.dart`
- `lib/domain/models/recitation_file.dart`
- `testing/packs/`
- `test/integrity/`
- The tests that mirror these files (same path under test/, ending in _test.dart)
- `test/guards/allow/pack_text/producers/p1-06-*.txt`

### Do not touch
`lib/data/repositories/`, `lib/data/services/manifest_signature.dart`, `tools/packs/`
(the pipeline builds v2 later, as stream B work), `lib/ui/`.

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

- `docs(packs): specify pack format v2 (SR-03)`
- `feat(packs): read search forms, tafsir and recitation packs (TF-04)`
- `test(packs): synthetic v2 packs and integrity checks (AU-13)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
