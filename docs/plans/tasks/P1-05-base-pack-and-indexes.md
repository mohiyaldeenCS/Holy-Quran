# P1-05 — Base pack bootstrap, run-time verification, Ed25519, Quran indexes (M1.2, M1.3, M1.4)

Wave 1 · Agent `data-builder` · Key 1 · Cap $25 · Base `main` · Needs: P1-02, P1-03.

## Why

- `RD-01`: «عرض القرآن كاملًا برواية حفص بالرسم العثماني من الحزمة المضمّنة، دون اتصال»;
  criterion «القراءة والفهارس تعمل دون اتصال من أول تشغيل».
- PRD §9.5: «عند أول تشغيل بعد التثبيت أو التحديث تُتحقق بصمة الحزمة الأساسية كاملة.
  عند فتح سورة تُتحقق بصمتها مرة في الجلسة. إذا فشل التحقق: لا يُعرض النص من تلك
  الحزمة، ويظهر تنبيه السلامة، ويُعاد استخراج الحزمة الأساسية من التطبيق».
- `OF-05` (signature part): «كل ملف يُتحقق ببصمته وبتوقيع بيان حزمته قبل تفعيله».
- Data for `NV-01`, `NV-02`, `RD-05`, `RD-06`, `RD-17`: divisions, page boundaries,
  surah facts.

Read `docs/CONTENT_PACKS.md` ("Verification order in the app"), D-080, and D-107 and
D-108 in `docs/plans/PHASE1.md` §6.

## Plan first

Ask `flutter-architect` for a file-level plan; check first what `EditionMap`,
`PackQuranTextRepository` and `LocalPackRepository` already do, and reuse them.

## Do

Work in this order, because eight wave-2 tasks wait on the index: 5, then 1 to 3,
then 4. If the budget runs short, commit what is done and report where you stopped.

1. `lib/data/services/base_pack_service.dart`: the base pack will ship under
   `assets/packs/<id>/<version>/` once B0.2 signs it (D-030); its id and version live
   in `lib/config/base_pack.dart`. On first run and after an app update, copy it to
   the application-support directory, verify it completely, and remember the result
   for that app version. On failure, copy it again once; if it fails again, report
   the failure. No bundled pack yet means the state `missing`.
2. Per-surah verification once per session: confirm or add it in the text
   repository; a surah whose digest fails is never served.
3. `PackIntegrityRepository` (abstract and implementation): per pack, `ok`,
   `missing`, `repairing` or `failed(reason)`, as a `Listenable`, plus a stream of
   integrity events (P1-18 stores them; P1-26 shows the alert). While the base pack is
   failed, the text repository returns a failure, never text.
4. `ManifestSignatureVerifier` with Ed25519 (`cryptography`) per D-080:
   `manifest.json.sig` is the raw 64-byte signature of the exact bytes of
   `manifest.json`; accepted public keys come from `lib/config/signing_keys.dart`,
   empty until O-03. Results: `valid`, `invalid` (bad signature, wrong length),
   `notChecked` (no key configured or no signature file). The activation policy
   belongs to P1-07; do not add it here.
5. `QuranIndexRepository` (abstract and implementation): surahs with their facts
   (name as `PackText`, ayah count, place, order, first page), juz, hizb and rub lists
   with first ayah and page, the position of an address (surah, juz, hizb, rub, page),
   the page boundaries inside a surah, the sajda ayat. It implements P1-02's
   `QuranStructure`.
6. Fill `lib/config/providers/quran_providers.dart`; fakes
   `testing/fakes/fake_quran_index_repository.dart` and
   `testing/fakes/fake_pack_integrity_repository.dart`.

## Tests

Bootstrap with a synthetic pack in a fake asset bundle: first run, update, corrupt
copy repaired once, then failed; no text served while failed; per-surah check once per
session; Ed25519 with a key pair generated in the test (never a committed private key):
valid, tampered, wrong length, no key; index answers on a synthetic pack, including a
surah crossing pages and a sajda.

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
- `lib/data/services/base_pack_service.dart`
- `lib/data/services/manifest_signature.dart`
- `lib/data/repositories/local_pack_repository.dart`
- `lib/data/repositories/pack_quran_text_repository.dart`
- `lib/data/repositories/quran_text_repository.dart`
- `lib/data/repositories/quran_index_repository.dart`
- `lib/data/repositories/pack_integrity_repository.dart`
- `lib/domain/models/quran_position.dart`
- `lib/domain/models/division_entry.dart`
- `lib/domain/models/pack_integrity.dart`
- `lib/config/base_pack.dart`
- `lib/config/signing_keys.dart`
- `lib/config/providers/quran_providers.dart`
- `testing/fakes/fake_quran_index_repository.dart`
- `testing/fakes/fake_pack_integrity_repository.dart`
- The tests that mirror these files (same path under test/, ending in _test.dart)
- `test/guards/allow/pack_text/carriers/p1-05-quran-index.txt` (if the index repository carries `PackText`)

### Do not touch
`lib/data/services/pack_database.dart`, `lib/data/models/pack_manifest_json.dart`,
`lib/domain/models/pack_manifest.dart`, `testing/packs/`, `test/integrity/` (P1-06
owns them in this wave; if you need a change there, report it), `assets/`.

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

- `feat(packs): bootstrap and verify the bundled base pack (RD-01)`
- `feat(packs): verify manifest signatures with Ed25519 (OF-05)`
- `feat(index): read divisions, page boundaries and surah facts (NV-02)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
