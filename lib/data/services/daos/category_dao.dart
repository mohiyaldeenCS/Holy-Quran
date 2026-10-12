import 'package:drift/drift.dart';

import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/data/services/user_tables.dart';
import 'package:holyquran/utils/ids.dart';

part 'category_dao.g.dart';

/// Bookmark and note categories (`UD-01`, `UD-04`).
@DriftAccessor(tables: [Category])
class CategoryDao extends DatabaseAccessor<UserDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.attachedDatabase);

  /// Makes a row for each of [builtinKeys] that has none, deleted or not,
  /// and returns every live category.
  Future<List<CategoryRow>> withBuiltins(
    Iterable<String> builtinKeys, {
    required int at,
  }) => transaction(() async {
    final stored = {
      for (final row in await select(category).get()) row.builtinKey,
    };
    for (final key in builtinKeys) {
      if (stored.contains(key)) continue;
      await into(category).insert(
        CategoryCompanion.insert(
          id: newId(),
          updatedAt: at,
          builtinKey: Value(key),
          createdAt: at,
        ),
      );
    }
    return (select(category)..where((c) => c.deleted.not())).get();
  });
}
