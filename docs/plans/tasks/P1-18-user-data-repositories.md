# P1-18 — User data repositories (M1.6, M1.8, M1.9)

Wave 2 · Agent `data-builder` · Key 2 · Cap $25 · Base `main` · Needs: P1-04, P1-05.

## Why

- `UD-01` «علامة مرجعية على آية كاملة. لكل علامة تصنيف واحد»; `UD-02` «وسوم حرة مشتركة بين
  العلامات والملاحظات»; `UD-03` «ترتيب بالأحدث أو بترتيب المصحف، تصفية بالتصنيف والوسم،
  وبحث»; `UD-04` «ملاحظة نصية مرتبطة بآية، بتصنيف ووسوم. يجوز أكثر من ملاحظة للآية»;
  `UD-05` data; `UD-07` «الحذف مع مهلة تراجع. لا تُحذف بيانات عند تغيير المستوى أو حذف
  حزمة».
- `SR-08` (search in bookmarks and notes), `SR-10` (local history that can be
  cleared), `AU-16` (last listening position), `RD-16` (keep the screen awake), PRD
  §9.5 «الحدث يُسجَّل محليًا».
- Criterion: «بيانات المستخدم تبقى بعد تحديث التطبيق وبعد تحديث أي حزمة». `NF-14`: never
  sent anywhere.

Read D-104 to D-106 in `docs/plans/PHASE1.md` §6 and P1-04's schema v1.

## Do

1. DAOs in `lib/data/services/daos/` and repositories (abstract and local) for
   bookmarks, categories (the four built-in ones of `Tag`; no API to create a
   category until O-14), tags, notes, listening position, search history and the
   integrity log (subscribed to P1-05's event stream).
2. Delete with undo: a soft delete with a tombstone and a restore within the undo
   window; nothing is ever deleted by a level change or a pack deletion.
3. Lists: newest or mushaf order (by address), filter by category and tag, and a text
   search over note bodies and tag names. Note bodies are user text: compare the
   query with them simply; if P1-21's query fold suits, P1-24 may switch later.
4. `lib/data/services/wakelock_service.dart` (`wakelock_plus`) and
   `KeepAwakeRepository`: on only while the setting is on and the reader or the
   player says it is active.
5. Fill `lib/config/providers/user_data_providers.dart`; fakes in `testing/fakes/` for
   every repository.
6. Schema v1 is P1-04's: if a column is missing, do not change the schema; report it.

## Tests

Create, change, filter, order and search; several notes on one ayah; undo within the
window and permanence after it; rows survive closing and reopening the database; the
integrity log stores events; history cleared; keep-awake follows setting and activity.

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
- `lib/data/services/daos/bookmark_dao.dart`, `category_dao.dart`, `tag_dao.dart`, `note_dao.dart`, `listening_position_dao.dart`, `search_history_dao.dart`, `integrity_log_dao.dart`, and their `.g.dart`
- `lib/data/services/wakelock_service.dart`
- `lib/data/repositories/bookmark_repository.dart`, `category_repository.dart`, `tag_repository.dart`, `note_repository.dart`, `listening_position_repository.dart`, `search_history_repository.dart`, `integrity_log_repository.dart`, `keep_awake_repository.dart`
- `lib/domain/models/bookmark.dart`, `category.dart`, `user_tag.dart` (not `Tag`, the widget's name), `note.dart`, `listening_position.dart`
- `lib/config/providers/user_data_providers.dart`
- One fake per repository, testing/fakes/fake_<repository>.dart
- The tests that mirror these files (same path under test/, ending in _test.dart)

### Do not touch
`lib/data/services/user_database.dart`, `user_tables.dart`, P1-04's DAOs and
repositories, `lib/ui/`.

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

- `feat(bookmarks): bookmarks, categories, tags and notes with undo (UD-07)`
- `feat(audio): store the last listening position (AU-16)`
- `feat(search): local search history (SR-10)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
