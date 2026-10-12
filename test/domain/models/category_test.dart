import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/category.dart';

void main() {
  test('each has a stable key that reads back as itself', () {
    expect(BuiltinCategory.values.map((c) => c.key), [
      'memorise',
      'review',
      'study',
      'important',
    ]);
    for (final category in BuiltinCategory.values) {
      expect(BuiltinCategory.fromKey(category.key), category);
    }
    expect(BuiltinCategory.fromKey('a-later-key'), isNull);
    expect(BuiltinCategory.fromKey(null), isNull);
  });

  test('is equal by id and built-in', () {
    const a = Category(id: 'a', builtin: BuiltinCategory.study);
    expect(a, const Category(id: 'a', builtin: BuiltinCategory.study));
    expect(
      a.hashCode,
      const Category(id: 'a', builtin: BuiltinCategory.study).hashCode,
    );
    expect(a, isNot(const Category(id: 'a', builtin: BuiltinCategory.review)));
    expect(a, isNot(const Category(id: 'b', builtin: BuiltinCategory.study)));
    expect('$a', 'Category(a, study)');
  });
}
