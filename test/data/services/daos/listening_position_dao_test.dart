import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/daos/listening_position_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late ListeningPositionDao dao;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    dao = ListeningPositionDao(db);
  });
  tearDown(() => db.close());

  test('reads nothing before the first write', () async {
    expect(await dao.read(), isNull);
  });

  test('keeps one row and changes it', () async {
    await dao.write('hafs:2:5', 'synthetic-reciter', 1500, updatedAt: 10);
    final first = (await dao.read())!;
    await dao.write('hafs:3:1', 'other-reciter', 0, updatedAt: 20);
    final second = (await dao.read())!;

    expect(first.address, 'hafs:2:5');
    expect(first.recitationId, 'synthetic-reciter');
    expect(first.offsetMs, 1500);
    expect(second.id, first.id);
    expect(second.address, 'hafs:3:1');
    expect(second.recitationId, 'other-reciter');
    expect(second.offsetMs, 0);
    expect(second.updatedAt, 20);
    expect(await db.select(db.listeningPosition).get(), hasLength(1));
  });

  test(
    'reads a deleted row as none, and a write clears its tombstone',
    () async {
      await dao.write('hafs:2:5', 'synthetic-reciter', 1500, updatedAt: 10);
      await db
          .update(db.listeningPosition)
          .write(const ListeningPositionCompanion(deleted: Value(true)));
      expect(await dao.read(), isNull);

      await dao.write('hafs:2:6', 'synthetic-reciter', 0, updatedAt: 20);
      expect((await dao.read())!.address, 'hafs:2:6');
    },
  );
}
