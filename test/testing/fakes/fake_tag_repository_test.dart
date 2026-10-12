import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_tag_repository.dart';

void main() {
  test('creates once per name, renames, deletes and restores', () async {
    final tags = FakeTagRepository();

    final beta = (await tags.create('tag-beta') as Ok<UserTag>).value;
    final alpha = (await tags.create('tag-alpha') as Ok<UserTag>).value;
    expect((await tags.create('tag-beta') as Ok<UserTag>).value, beta);
    expect((await tags.tags() as Ok<List<UserTag>>).value, [alpha, beta]);

    await tags.rename(alpha.id, 'tag-gamma');
    await tags.delete(beta.id);
    expect(
      (await tags.tags() as Ok<List<UserTag>>).value.single.name,
      'tag-gamma',
    );
    await tags.restore(beta.id);
    expect((await tags.tags() as Ok<List<UserTag>>).value, hasLength(2));
    expect(await tags.create(''), isA<Failure<UserTag>>());
  });

  test('keeps names unique among live tags', () async {
    final tags = FakeTagRepository();
    final old = (await tags.create('x') as Ok<UserTag>).value;
    await tags.delete(old.id);
    final current = (await tags.create('x') as Ok<UserTag>).value;
    final other = (await tags.create('y') as Ok<UserTag>).value;

    expect((await tags.restore(old.id) as Failure).error, isA<TagNameTaken>());
    expect(
      (await tags.rename(other.id, 'x') as Failure).error,
      isA<TagNameTaken>(),
    );
    expect(await tags.rename(current.id, 'x'), isA<Ok<void>>());
    expect(await tags.restore(current.id), isA<Ok<void>>());
  });
}
