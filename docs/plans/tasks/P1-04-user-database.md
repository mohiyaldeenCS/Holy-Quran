# P1-04 — User database v1, settings, reading position, level policy (M1.1, M1.2)

Wave 1 · Agent `data-builder` · Key 2 · Cap $25 · Base `main` · Needs: P1-02, P1-03.

## Why

- `NF-08`: «بقاء بيانات المستخدم عند ترقية التطبيق أو أي حزمة | اختبار ترحيل مع كل إصدار».
- The bookmark module's criterion: «بيانات المستخدم تبقى بعد تحديث التطبيق وبعد تحديث أي حزمة».
- `RD-12` stores «أول آية ظاهرة»; `RD-13` and `RD-16` are settings; `RD-08` persists
  the theme and follow-system choice (D-050, D-053); `LV-01` «إعداد واحد بثلاثة
  مستويات، والافتراضي «بسيط»»; `LV-03` «ما يظهر في كل مستوى يتبع مصفوفة القسم 7.3».
- `NF-13`, `NF-14`: local by default; reading history and notes are sensitive.

Read D-104, D-105 and D-106 in `docs/plans/PHASE1.md` §6, and `docs/ARCHITECTURE.md`,
"User data".

## Plan first

Ask `flutter-architect` through the Task tool for a file-level plan of the schema,
the drift set-up (`build.yaml`, schema dumps, generated migration helpers) and the
settings store. Keep to this task's list.

## Do

1. `lib/data/services/user_database.dart`: drift over its native backend on the
   bundled SQLite (D-061), file `user.sqlite` in the application-support directory;
   in memory in tests. Tables in `lib/data/services/user_tables.dart`, schema v1,
   every Phase 1 table: `settings` (key, typed value, `updated_at`);
   `reading_position` and `listening_position` (one row each; address, and for
   listening the recitation id and the offset in ms); `category` (built-in key or
   user name, colour and shape slots, for the four categories of `Tag`; «تفسير» and
   user-made ones wait for O-14); `bookmark` (ayah address, category, created and
   updated times); `tag`; `bookmark_tag`; `note` (ayah address, body, category,
   times); `note_tag`; `search_history` (query, time); `integrity_event` (pack id,
   version, kind, detail, time). Every synced kind of row has a random 128-bit id,
   `updated_at` and a deletion tombstone. Addresses are canonical strings (D-063). No
   column holds Quran text.
2. `lib/utils/ids.dart`: random 128-bit ids from `Random.secure`.
3. Schema dump `drift_schemas/user/drift_schema_v1.json` and the generated migration
   helpers; a migration test that will grow with every version.
4. `lib/data/services/settings_store.dart`: typed get and set over `settings` (bool,
   int, double, string, enum by name), all rows read once at start so that the first
   frame has them, writes through.
5. `lib/domain/models/ui_level.dart` and `lib/domain/models/level_policy.dart`: the
   matrix of PRD §7.3 for the Phase 1 tools, pure Dart (word sheet from «متوسط», per
   §7.4; everything else of Phase 1 at every level).
6. `AppSettingsRepository` (abstract and local, `lib/data/repositories/`): theme,
   follow-system dark, level (default «بسيط»), level chosen at first run, open at the
   last position, keep the screen awake, surah text step. Exposed as a `Listenable`.
7. `ReadingPositionRepository` (abstract and local): save an ayah address, read the
   last one, `Listenable`.
8. DAOs in `lib/data/services/daos/`, not listed in `@DriftDatabase(daos: …)`.
9. Fill `lib/config/providers/{user_database,settings,reading}_providers.dart`.
10. Never import `package:sqlite3` (the pack-write guard allows it only in
    `pack_database.dart`, D-061); use `package:drift/native.dart`.
11. Fakes for later UI tasks: `testing/fakes/fake_app_settings_repository.dart`,
    `testing/fakes/fake_reading_position_repository.dart`.

## Tests

Schema and defaults; values survive closing and reopening a file database in a temp
folder; the migration test from v1; no table has a column for pack text; settings are
available synchronously after start; the level policy against the §7.3 table; ids are
unique and 128-bit.

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
- `lib/data/services/user_database.dart` and `user_database.g.dart`
- `lib/data/services/user_tables.dart`
- `lib/data/services/settings_store.dart`
- `lib/data/services/daos/settings_dao.dart`, `reading_position_dao.dart` and their `.g.dart`
- `lib/data/repositories/app_settings_repository.dart`
- `lib/data/repositories/reading_position_repository.dart`
- `lib/domain/models/ui_level.dart`
- `lib/domain/models/level_policy.dart`
- `lib/utils/ids.dart`
- `lib/config/providers/user_database_providers.dart`
- `lib/config/providers/settings_providers.dart`
- `lib/config/providers/reading_providers.dart`
- `build.yaml` (handed over for this task)
- `drift_schemas/user/`
- `testing/fakes/fake_app_settings_repository.dart`
- `testing/fakes/fake_reading_position_repository.dart`
- `test/data/services/user_database_test.dart`
- `test/data/services/migrations/`
- `test/data/services/settings_store_test.dart`
- `test/data/repositories/app_settings_repository_test.dart`
- `test/data/repositories/reading_position_repository_test.dart`
- `test/domain/models/level_policy_test.dart`
- `test/utils/ids_test.dart`

### Do not touch
`lib/data/services/pack_*.dart`, `lib/ui/`, `pubspec.*`, other tasks' files.

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

- `feat(db): add the user database schema v1 with its migration test (M1.2)`
- `feat(settings): add the settings store and app settings (M1.1)`
- `feat(reader): store the last reading position (RD-12)`
- `feat(levels): add the level policy of PRD 7.3 (LV-03)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
