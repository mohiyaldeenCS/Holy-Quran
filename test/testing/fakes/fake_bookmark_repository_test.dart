import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_bookmark_repository.dart';

void main() {
  test('adds one bookmark per ayah, lists, deletes and restores', () async {
    final bookmarks = FakeBookmarkRepository(tagNames: {'t': 'tag-alpha'});
    var notified = 0;
    bookmarks.addListener(() => notified++);
    final ayah = QuranAddress.parse('hafs:2:5');

    final added =
        (await bookmarks.add(ayah, 'category-a') as Ok<Bookmark>).value;
    final again =
        (await bookmarks.add(ayah, 'category-b') as Ok<Bookmark>).value;
    await bookmarks.setTags(added.id, {'t'});

    expect(again.id, added.id);
    expect((await bookmarks.bookmarkAt(ayah) as Ok<Bookmark?>).value!.tagIds, {
      't',
    });
    expect(
      (await bookmarks.list(query: 'alpha') as Ok<List<Bookmark>>).value,
      hasLength(1),
    );
    expect(
      (await bookmarks.list(categoryId: 'category-a') as Ok<List<Bookmark>>)
          .value,
      isEmpty,
    );
    await bookmarks.delete(added.id);
    expect(
      (await bookmarks.bookmarkedAyat() as Ok<Set<QuranAddress>>).value,
      isEmpty,
    );
    await bookmarks.restore(added.id);
    expect(await bookmarks.setCategory('absent', 'c'), isA<Failure<void>>());
    expect(notified, 5);
  });

  test('restores like the real repository', () async {
    final bookmarks = FakeBookmarkRepository();
    final ayah = QuranAddress.parse('hafs:2:5');
    final old = (await bookmarks.add(ayah, 'category-a') as Ok<Bookmark>).value;
    await bookmarks.delete(old.id);
    final current =
        (await bookmarks.add(ayah, 'category-b') as Ok<Bookmark>).value;
    var notified = 0;
    bookmarks.addListener(() => notified++);

    final result = await bookmarks.restore(old.id);

    expect((result as Failure).error, isA<AyahAlreadyBookmarked>());
    expect(await bookmarks.restore(current.id), isA<Ok<void>>());
    expect(notified, 0);
  });

  test('fails every call while a failure is set', () async {
    final bookmarks = FakeBookmarkRepository()
      ..failure = const FormatException('synthetic failure');

    expect(
      await bookmarks.add(QuranAddress.parse('hafs:2:5'), 'c'),
      isA<Failure<Bookmark>>(),
    );
    expect(await bookmarks.list(), isA<Failure<List<Bookmark>>>());
    expect(await bookmarks.setCategory('a', 'c'), isA<Failure<void>>());
  });
}
