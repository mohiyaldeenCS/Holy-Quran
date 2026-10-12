# P1-13 — Pack catalogue and recitation listing (M1.4, M1.9)

Wave 2 · Agent `data-builder` · Key 1 · Cap $30 · Base `main` · Needs: P1-05, P1-06,
P1-07.

## Why

- `NF-19`: «إضافة تفسير أو تلاوة أو رواية دون إصدار جديد للتطبيق | بحزمة وبيان موقّع فقط».
- `AU-01` data: «اختيار التلاوة مع عرض الرواية والنمط وحالة التنزيل وتوفر توقيت الكلمات»;
  criterion «لا تظهر في القائمة تلاوة ليس لها سجل حقوق مكتمل».
- `OF-02` data (name, size, state, source and version); `TF-01` data (downloaded
  apart from available); `TF-06`: «تفسير مختصر واحد يُنزَّل عند أول استخدام».

Read D-107 to D-110 in `docs/plans/PHASE1.md` §6, `docs/CONTENT_PACKS.md` v2, and the
installer of P1-07.

## Do

1. `docs/PACK_CATALOGUE.md` (new, handed over): `catalogue.json` and its detached
   Ed25519 signature `catalogue.json.sig` (the scheme of D-080); fields: format
   version, date, packs (id, kind, version, title, size, manifest and file URLs with
   bytes and SHA-256, the source summary for the badge, change summary, and a role
   `first-use-tafsir` on the one short tafsir fetched at first use), recitations (id,
   reciter, riwaya, style, unit, qualities, the id of its recitation pack, rights
   complete, word timing). Unknown fields rejected.
2. Parser and `CatalogueRepository`: fetch over HTTPS from the address in
   `lib/config/catalogue_config.dart` (empty until O-08: state "not configured"),
   verify the signature with P1-05's verifier and the same policy as P1-07, keep the
   last good catalogue on disk for offline use, and join it with the installed packs
   into a resource state (available, downloading with percent, downloaded, update
   available).
3. A recitation pack is verified once per session through P1-05's
   `PackIntegrityRepository`; a failed one serves nothing.
4. `RecitationRepository`: recitations whose rights are complete, and nothing else;
   for one recitation, the file of a surah or ayah at a quality, local when
   downloaded, otherwise its stream URL, from its recitation pack (P1-06).
5. Fill `lib/config/providers/catalogue_providers.dart`; fakes
   `testing/fakes/fake_catalogue_repository.dart`,
   `testing/fakes/fake_recitation_repository.dart`.

## Tests

A local server with a synthetic catalogue: valid, invalid and unsigned under the
policy; a recitation without complete rights never listed; update detection; offline
fallback to the cached copy; local file preferred over the stream.

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
- `docs/PACK_CATALOGUE.md` (new, handed over)
- `lib/data/models/catalogue_json.dart`
- `lib/data/services/catalogue_service.dart`
- `lib/data/repositories/catalogue_repository.dart`
- `lib/data/repositories/recitation_repository.dart`
- `lib/domain/models/catalogue.dart`
- `lib/domain/models/catalogue_entry.dart`
- `lib/domain/models/resource_state.dart`
- `lib/config/catalogue_config.dart`
- `lib/config/providers/catalogue_providers.dart`
- `testing/fakes/fake_catalogue_repository.dart`
- `testing/fakes/fake_recitation_repository.dart`
- The tests that mirror these files (same path under test/, ending in _test.dart)

### Do not touch
P1-05, P1-06 and P1-07's files (report a needed change), `lib/ui/`.

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

- `docs(resources): specify the signed pack catalogue (NF-19)`
- `feat(resources): fetch and verify the catalogue (NF-19)`
- `feat(audio): list recitations with complete rights only (AU-01)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
