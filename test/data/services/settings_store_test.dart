import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/settings_store.dart';
import 'package:holyquran/data/services/user_database.dart';

enum _Shade { light, dark }

final class _FailingDao extends SettingsDao {
  _FailingDao(super.attachedDatabase);

  @override
  Future<void> write(
    String key,
    StoredSetting value, {
    required int updatedAt,
  }) async => throw const FormatException('synthetic failure');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late SettingsDao dao;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    dao = SettingsDao(db);
  });
  tearDown(() => db.close());

  test('a missing value reads as null', () async {
    final store = await SettingsStore.load(dao);

    expect(store.readBool('synthetic.a'), isNull);
    expect(store.readInt('synthetic.a'), isNull);
    expect(store.readDouble('synthetic.a'), isNull);
    expect(store.readString('synthetic.a'), isNull);
    expect(store.readEnum('synthetic.a', _Shade.values), isNull);
  });

  test('every type round-trips, in memory and through the table', () async {
    final store = await SettingsStore.load(dao);
    await store.writeBool('synthetic.bool', true);
    await store.writeInt('synthetic.int', -3);
    await store.writeDouble('synthetic.double', 1.15);
    await store.writeString('synthetic.string', 'synthetic value');
    await store.writeEnum('synthetic.enum', _Shade.dark);

    for (final read in [store, await SettingsStore.load(dao)]) {
      expect(read.readBool('synthetic.bool'), isTrue);
      expect(read.readInt('synthetic.int'), -3);
      expect(read.readDouble('synthetic.double'), 1.15);
      expect(read.readString('synthetic.string'), 'synthetic value');
      expect(read.readEnum('synthetic.enum', _Shade.values), _Shade.dark);
    }
  });

  test('values are there synchronously once loaded', () async {
    await dao.write('synthetic.int', (
      intValue: 4,
      realValue: null,
      textValue: null,
    ), updatedAt: 1);

    final store = await SettingsStore.load(dao);

    expect(store.readInt('synthetic.int'), 4);
  });

  test('a later write replaces the value and its type', () async {
    final store = await SettingsStore.load(dao);
    await store.writeInt('synthetic.key', 2);
    await store.writeString('synthetic.key', 'synthetic');

    final reloaded = await SettingsStore.load(dao);
    expect(reloaded.readInt('synthetic.key'), isNull);
    expect(reloaded.readString('synthetic.key'), 'synthetic');
  });

  test('a value of another type reads as null', () async {
    final store = await SettingsStore.load(dao);
    await store.writeInt('synthetic.int', 2);
    await store.writeString('synthetic.string', 'synthetic');

    expect(store.readBool('synthetic.int'), isNull);
    expect(store.readDouble('synthetic.int'), isNull);
    expect(store.readString('synthetic.int'), isNull);
    expect(store.readEnum('synthetic.string', _Shade.values), isNull);
  });

  test('a write is stamped with the clock', () async {
    final store = await SettingsStore.load(dao, now: () => 1234);
    await store.writeBool('synthetic.bool', false);

    final row = await db.select(db.settings).getSingle();
    expect(row.updatedAt, 1234);
    expect(row.intValue, 0);
  });

  test('a failed write throws and leaves the value unchanged', () async {
    await dao.write('synthetic.int', (
      intValue: 1,
      realValue: null,
      textValue: null,
    ), updatedAt: 1);
    final store = await SettingsStore.load(_FailingDao(db));

    await expectLater(
      store.writeInt('synthetic.int', 2),
      throwsFormatException,
    );
    expect(store.readInt('synthetic.int'), 1);
  });
}
