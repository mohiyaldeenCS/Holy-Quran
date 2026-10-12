import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/daos/search_history_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late SearchHistoryDao dao;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    dao = SearchHistoryDao(db);
  });
  tearDown(() => db.close());

  test(
    'reads by order of recording, newest first, whatever the clock',
    () async {
      await dao.record('query-a', at: 10);
      await dao.record('query-b', at: 30);
      await dao.record('query-c', at: 20);

      expect(await dao.queries(), ['query-c', 'query-b', 'query-a']);
    },
  );

  test('a recorded query moves to the top, once', () async {
    await dao.record('query-a', at: 10);
    await dao.record('query-b', at: 20);
    await dao.record('query-a', at: 30);

    expect(await dao.queries(), ['query-a', 'query-b']);
    expect(await db.select(db.searchHistory).get(), hasLength(2));
  });

  test('clear removes every row', () async {
    await dao.record('query-a', at: 10);
    await dao.clear();

    expect(await db.select(db.searchHistory).get(), isEmpty);
  });
}
