import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/daos/reading_position_dao.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

// User data survives every app upgrade (NF-08). Each new schema version adds
// its dump, its generated helpers and a data-integrity test from the
// version before it.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('the schema dumps reach the current version', () {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(GeneratedHelper.versions.last, db.schemaVersion);
  });

  for (final from in GeneratedHelper.versions) {
    test('opening a v$from database gives the current schema', () async {
      final schema = await verifier.schemaAt(from);
      final db = UserDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, GeneratedHelper.versions.last);
      await db.close();
    });
  }

  test('rows written at v1 are read back at the current version', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: GeneratedHelper.versions.last,
      createOld: v1.DatabaseAtV1.new,
      createNew: UserDatabase.new,
      openTestedDatabase: UserDatabase.new,
      createItems: (batch, old) {
        batch.insert(
          old.settings,
          v1.SettingsCompanion.insert(
            key: 'synthetic.flag',
            intValue: const Value(1),
            updatedAt: 5,
          ),
        );
        batch.insert(
          old.readingPosition,
          v1.ReadingPositionCompanion.insert(
            id: '0123456789abcdef0123456789abcdef',
            address: 'hafs:3:4',
            updatedAt: 5,
          ),
        );
      },
      validateItems: (db) async {
        final settings = await SettingsDao(db).readAll();
        expect(settings['synthetic.flag']?.intValue, 1);
        expect(await ReadingPositionDao(db).readAddress(), 'hafs:3:4');
      },
    );
  });
}
