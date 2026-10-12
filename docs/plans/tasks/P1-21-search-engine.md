# P1-21 — Search engine, tafsir search included (M1.8)

Wave 2 · Agent `data-builder` · Key 1 · Cap $30 · Base `main` · Needs: P1-06, P1-10.

## Why

- `SR-02` «البحث بآية كاملة، بجزء منها عبارةً متتابعة، وبكلمات متفرقة»; `SR-03` matching
  on the source's search forms; `SR-05` order (mushaf, nearest, most frequent) and
  `SR-06` scope (whole Quran, surah, juz) in the engine; `TF-07` «البحث داخل تفسير محدد،
  وفي عدة تفاسير منزَّلة معًا».
- Criteria: «مجموعة اختبار ذهبية من 200 استعلام على الأقل بعدد مواضع معلوم لكل استعلام:
  المطابقة تامة»; «النتائج تظهر خلال 300 مللي ثانية دون اتصال على الجهاز المرجعي»; «نص
  الآية في النتيجة مطابق لنص الحزمة، والإبراز لا يغيّر حرفًا». `NF-03`.

Read D-037 and D-118 (`docs/plans/PHASE1.md` §6) and `docs/ARCHITECTURE.md`, "Search".
The golden query set is B0.10's (not delivered): build the harness that will run it.

## Plan first

Ask `flutter-architect` for the index design and the 300 ms budget.

## Do

1. `lib/domain/models/query_fold.dart`: one table-driven fold applied to the user's
   query only. The stored forms are matched as the pack gives them, per form kind
   (P1-06), never folded unless D-037's decision against the golden set says so.
   Identifiers must not match the pack-text guard's patterns (normalise, diacritic,
   NFC, NFD), and sinks call the fold rather than any string-changing method. Start
   with what «بلا تشكيل» needs on the query side; every further rule (hamza seats, alef forms) is a decision to take
   against the golden set: list them as questions, do not add them.
2. `SearchRepository`: modes (whole ayah, phrase of consecutive words, scattered
   words in one ayah) over the pack's search forms; matches as word ranges with
   addresses, so highlighting uses stored offsets and changes no character; order by
   mushaf, by closeness (exact phrase first, then fewer gaps) and by frequency (ayat
   with most occurrences first); scope by surah or juz.
3. The index: built from the search forms on first use, in memory or in a cache file
   outside the pack (D-118). Its builder reads pack text: a sink entry.
4. `TafsirSearchRepository`: the same fold over installed tafsir passages, one or
   several books; results as passages with match offsets; never a substring cut
   outside the pack's boundaries.
5. `golden_query_harness.dart` under `testing/`: reads a query file of B0.10's format
   (query, expected count) and reports every mismatch; run on a synthetic set now.
6. Fill `lib/config/providers/search_providers.dart`; fakes.

## Tests

Each mode on synthetic forms; ordering and scope; match offsets slice the pack's
words exactly; the budget: a synthetic pack of 6,236 ayat answers a query within
300 ms on the CI runner after the index is built (report the numbers; the device
check is P1-36's); tafsir search across two synthetic books.

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
- `lib/domain/models/query_fold.dart`
- `lib/domain/models/search_query.dart`, `search_match.dart`, `search_hit.dart`
- `lib/data/services/search_index_service.dart`
- `lib/data/repositories/search_repository.dart`
- `lib/data/repositories/tafsir_search_repository.dart`
- `lib/config/providers/search_providers.dart`
- `testing/search/golden_query_harness.dart`
- `testing/fakes/fake_search_repository.dart`, `fake_tafsir_search_repository.dart`
- The tests that mirror these files (same path under test/, ending in _test.dart)
- `test/guards/allow/pack_text/sinks/p1-21-search-index.txt`, `p1-21-tafsir-search.txt`

### Do not touch
P1-06 and P1-10's files, `lib/ui/`.

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

- `feat(search): search the pack's forms in three modes (SR-02)`
- `feat(search): order, scope and the golden query harness (SR-05)`
- `feat(search): search inside downloaded tafsirs (TF-07)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
