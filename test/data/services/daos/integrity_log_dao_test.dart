import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/daos/integrity_log_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late IntegrityLogDao dao;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    dao = IntegrityLogDao(db);
  });
  tearDown(() => db.close());

  test('appends entries and reads them newest first', () async {
    await dao.append(
      packId: 'synthetic-a',
      packVersion: 1,
      kind: 'ok',
      detail: null,
      occurredAt: 10,
    );
    await dao.append(
      packId: 'synthetic-b',
      packVersion: null,
      kind: 'failed',
      detail: 'synthetic detail',
      occurredAt: 20,
    );
    await dao.append(
      packId: 'synthetic-c',
      packVersion: 2,
      kind: 'missing',
      detail: null,
      occurredAt: 20,
    );

    final entries = await dao.entries();
    expect(entries.map((e) => e.packId), [
      'synthetic-c',
      'synthetic-b',
      'synthetic-a',
    ]);
    expect(entries[1].packVersion, isNull);
    expect(entries[1].kind, 'failed');
    expect(entries[1].detail, 'synthetic detail');
    expect(entries[2].packVersion, 1);
    expect(entries[2].detail, isNull);
  });
}
