import 'dart:io';

import 'package:drift/drift.dart' show DriftSqlType, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/daos/reading_position_dao.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

const _int = (intValue: 7, realValue: null, textValue: null);

// Every column of schema v1. A new column is a reviewed change: none may hold
// Quran text (CLAUDE.md, D-104); addresses are canonical strings.
const _columns = {
  'settings': ['key', 'int_value', 'real_value', 'text_value', 'updated_at'],
  'reading_position': ['id', 'updated_at', 'deleted', 'address'],
  'listening_position': [
    'id',
    'updated_at',
    'deleted',
    'address',
    'recitation_id',
    'offset_ms',
  ],
  'category': [
    'id',
    'updated_at',
    'deleted',
    'builtin_key',
    'name',
    'colour_slot',
    'shape_slot',
    'created_at',
  ],
  'bookmark': [
    'id',
    'updated_at',
    'deleted',
    'address',
    'category_id',
    'created_at',
  ],
  'tag': ['id', 'updated_at', 'deleted', 'name', 'created_at'],
  'bookmark_tag': ['bookmark_id', 'tag_id', 'updated_at', 'deleted'],
  'note': [
    'id',
    'updated_at',
    'deleted',
    'address',
    'body',
    'category_id',
    'created_at',
  ],
  'note_tag': ['note_id', 'tag_id', 'updated_at', 'deleted'],
  'search_history': ['id', 'query', 'searched_at'],
  'integrity_event': [
    'id',
    'pack_id',
    'pack_version',
    'kind',
    'detail',
    'occurred_at',
  ],
};

const _synced = [
  'reading_position',
  'listening_position',
  'category',
  'bookmark',
  'tag',
  'note',
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('schema v1', () {
    late UserDatabase db;

    setUp(() => db = UserDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('is version 1', () {
      expect(db.schemaVersion, 1);
    });

    test('has exactly the approved tables and columns', () {
      expect({
        for (final table in db.allTables)
          table.actualTableName: [
            for (final column in table.$columns) column.name,
          ],
      }, _columns);
    });

    test('synced rows have a text id, updated_at and a tombstone', () {
      for (final table in db.allTables) {
        if (!_synced.contains(table.actualTableName)) continue;
        final columns = {for (final c in table.$columns) c.name: c};
        expect(table.$primaryKey.map((c) => c.name), ['id']);
        expect(columns['id']!.type, DriftSqlType.string);
        expect(columns['updated_at']!.type, DriftSqlType.int);
        expect(columns['deleted']!.type, DriftSqlType.bool);
      }
    });

    test('join rows are keyed by their pair', () {
      final keys = {
        for (final table in db.allTables)
          table.actualTableName: table.$primaryKey.map((c) => c.name).toSet(),
      };
      expect(keys['bookmark_tag'], {'bookmark_id', 'tag_id'});
      expect(keys['note_tag'], {'note_id', 'tag_id'});
      expect(keys['settings'], {'key'});
    });

    test('starts empty', () async {
      expect(await SettingsDao(db).readAll(), isEmpty);
      expect(await ReadingPositionDao(db).readAddress(), isNull);
    });

    test('a new row is not deleted', () async {
      await ReadingPositionDao(db).writeAddress('hafs:1:2', updatedAt: 1);
      final row = await db.select(db.readingPosition).getSingle();
      expect(row.deleted, isFalse);
      expect(row.id, matches(RegExp(r'^[0-9a-f]{32}$')));
    });
  });

  group('a file database', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('user_database_test');
    });
    tearDown(() => directory.delete(recursive: true));

    test('keeps its rows after closing and reopening', () async {
      final file = File('${directory.path}/${UserDatabase.fileName}');
      final first = UserDatabase(NativeDatabase(file));
      await SettingsDao(first).write('synthetic.count', _int, updatedAt: 1);
      await ReadingPositionDao(first).writeAddress('hafs:2:3', updatedAt: 1);
      await first.close();

      final second = UserDatabase(NativeDatabase(file));
      addTearDown(second.close);
      expect((await SettingsDao(second).readAll())['synthetic.count'], _int);
      expect(await ReadingPositionDao(second).readAddress(), 'hafs:2:3');
    });

    testWidgets('open() makes user.sqlite in the application-support folder', (
      tester,
    ) async {
      final support = '${directory.path}/support';
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'getApplicationSupportDirectory' ? support : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      await tester.runAsync(() async {
        final db = await UserDatabase.open();
        await SettingsDao(db).write('synthetic.count', _int, updatedAt: 1);
        await db.close();
      });

      expect(File('$support/user.sqlite').existsSync(), isTrue);
    });
  });
}
