import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/daos/category_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late CategoryDao dao;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    dao = CategoryDao(db);
  });
  tearDown(() => db.close());

  test('withBuiltins makes each missing key once', () async {
    final first = await dao.withBuiltins(['key-a', 'key-b'], at: 10);
    final second = await dao.withBuiltins(['key-a', 'key-b', 'key-c'], at: 20);

    expect(
      first.map((row) => row.builtinKey),
      unorderedEquals(['key-a', 'key-b']),
    );
    expect(first.every((row) => row.createdAt == 10), isTrue);
    expect(second, hasLength(3));
    expect(second.toSet().containsAll(first), isTrue);
    expect(await db.select(db.category).get(), hasLength(3));
  });

  test('withBuiltins neither lists nor remakes a deleted key', () async {
    final [row] = await dao.withBuiltins(['key-a'], at: 10);
    await (db.update(db.category)..where((c) => c.id.equals(row.id))).write(
      const CategoryCompanion(deleted: Value(true)),
    );

    expect(await dao.withBuiltins(['key-a'], at: 20), isEmpty);
    expect(await db.select(db.category).get(), hasLength(1));
  });
}
