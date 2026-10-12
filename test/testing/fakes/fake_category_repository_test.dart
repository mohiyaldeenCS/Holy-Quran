import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_category_repository.dart';

void main() {
  test('lists the built-ins, or fails', () async {
    expect(
      (await FakeCategoryRepository().categories() as Ok<List<Category>>).value
          .map((c) => c.builtin),
      BuiltinCategory.values,
    );
    expect(
      await FakeCategoryRepository(
        failure: const FormatException('synthetic failure'),
      ).categories(),
      isA<Failure<List<Category>>>(),
    );
  });
}
