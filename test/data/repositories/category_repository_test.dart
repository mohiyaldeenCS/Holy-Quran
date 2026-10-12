import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/services/daos/category_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/utils/result.dart';

final class _FailingDao extends CategoryDao {
  _FailingDao(super.attachedDatabase);

  @override
  Future<List<CategoryRow>> withBuiltins(
    Iterable<String> builtinKeys, {
    required int at,
  }) async => throw const FormatException('synthetic failure');
}

List<Category> _value(Result<List<Category>> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => throw error,
};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;

  setUp(() => db = UserDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('makes the four built-ins once, in their order', () async {
    final categories = LocalCategoryRepository(CategoryDao(db), now: () => 7);

    final first = _value(await categories.categories());
    final second = _value(await categories.categories());

    expect(first.map((c) => c.builtin), BuiltinCategory.values);
    expect(first.map((c) => c.id).toSet(), hasLength(4));
    expect(second, first);
    final rows = await db.select(db.category).get();
    expect(rows, hasLength(4));
    expect(rows.every((row) => row.createdAt == 7 && row.name == null), isTrue);
    expect(
      rows.map((row) => row.builtinKey),
      unorderedEquals(BuiltinCategory.values.map((c) => c.key)),
    );
  });

  test('skips a row whose key is unknown or absent', () async {
    for (final (index, key) in ['a-later-key', null].indexed) {
      await db
          .into(db.category)
          .insert(
            CategoryCompanion.insert(
              id: 'stored-$index',
              updatedAt: 1,
              builtinKey: Value(key),
              name: const Value('synthetic name'),
              createdAt: 1,
            ),
          );
    }

    final categories = _value(
      await LocalCategoryRepository(CategoryDao(db)).categories(),
    );

    expect(categories.map((c) => c.builtin), BuiltinCategory.values);
  });

  test('a failing database returns a Failure', () async {
    expect(
      await LocalCategoryRepository(_FailingDao(db)).categories(),
      isA<Failure<List<Category>>>(),
    );
  });

  test('the ids survive closing and reopening a file database', () async {
    final directory = await Directory.systemTemp.createTemp('category_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/${UserDatabase.fileName}');

    final first = UserDatabase(NativeDatabase(file));
    final made = _value(
      await LocalCategoryRepository(CategoryDao(first)).categories(),
    );
    await first.close();

    final second = UserDatabase(NativeDatabase(file));
    addTearDown(second.close);
    expect(
      _value(await LocalCategoryRepository(CategoryDao(second)).categories()),
      made,
    );
    expect(await second.select(second.category).get(), hasLength(4));
  });
}
