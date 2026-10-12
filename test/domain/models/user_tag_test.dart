import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/user_tag.dart';

void main() {
  test('is equal by every field', () {
    final a = UserTag(
      id: 'a',
      name: 'tag-alpha',
      createdAt: DateTime.utc(2026),
    );

    expect(
      a,
      UserTag(id: 'a', name: 'tag-alpha', createdAt: DateTime.utc(2026)),
    );
    expect(
      a.hashCode,
      UserTag(
        id: 'a',
        name: 'tag-alpha',
        createdAt: DateTime.utc(2026),
      ).hashCode,
    );
    expect(
      a,
      isNot(UserTag(id: 'a', name: 'tag-beta', createdAt: DateTime.utc(2026))),
    );
    expect('$a', 'UserTag(a)');
  });
}
