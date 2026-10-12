import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/utils/result.dart';

/// The built-in categories with ids `fake-<name>`, or [failure] when it is
/// set.
final class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository({this.failure});

  Exception? failure;

  @override
  Future<Result<List<Category>>> categories() async {
    if (failure case final failure?) return Failure(failure);
    return Ok([
      for (final builtin in BuiltinCategory.values)
        Category(id: 'fake-${builtin.name}', builtin: builtin),
    ]);
  }
}
