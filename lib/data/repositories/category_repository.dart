import 'package:holyquran/data/services/daos/category_dao.dart';
import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/utils/result.dart';

/// The categories of bookmarks and notes (`UD-01`, `UD-04`). Until O-14 is
/// answered they are the built-in ones, and none is made, renamed or
/// deleted.
abstract interface class CategoryRepository {
  /// The built-in categories in the order of [BuiltinCategory], their rows
  /// made on first use.
  Future<Result<List<Category>>> categories();
}

/// [CategoryRepository] over the user database.
final class LocalCategoryRepository implements CategoryRepository {
  LocalCategoryRepository(this._dao, {this._now = _utcMilliseconds});

  final CategoryDao _dao;
  final int Function() _now;

  static int _utcMilliseconds() => DateTime.now().millisecondsSinceEpoch;

  /// A row with another key, such as one a later version made, is skipped.
  @override
  Future<Result<List<Category>>> categories() async {
    try {
      final rows = await _dao.withBuiltins(
        BuiltinCategory.values.map((category) => category.key),
        at: _now(),
      );
      final ids = {
        for (final row in rows)
          ?BuiltinCategory.fromKey(row.builtinKey): row.id,
      };
      return Ok([
        for (final builtin in BuiltinCategory.values)
          if (ids[builtin] case final id?) Category(id: id, builtin: builtin),
      ]);
    } on Exception catch (error) {
      return Failure(error);
    }
  }
}
