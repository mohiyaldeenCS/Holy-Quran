import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/quran_address.dart';

Bookmark _bookmark(
  String id,
  String address, {
  int created = 0,
  String categoryId = 'category-a',
  Set<String> tagIds = const {},
}) => Bookmark(
  id: id,
  address: QuranAddress.parse(address),
  categoryId: categoryId,
  tagIds: tagIds,
  createdAt: DateTime.utc(2026, 1, 1, 0, 0, created),
  updatedAt: DateTime.utc(2026, 1, 1, 0, 0, created),
);

void main() {
  test('refuses a word address', () {
    expect(() => _bookmark('a', 'hafs:2:5:1'), throwsArgumentError);
  });

  test('is equal by every field, tags in any order', () {
    expect(
      _bookmark('a', 'hafs:2:5', tagIds: {'x', 'y'}),
      _bookmark('a', 'hafs:2:5', tagIds: {'y', 'x'}),
    );
    expect(
      _bookmark('a', 'hafs:2:5', tagIds: {'y', 'x'}).hashCode,
      _bookmark('a', 'hafs:2:5', tagIds: {'x', 'y'}).hashCode,
    );
    expect(
      _bookmark('a', 'hafs:2:5'),
      isNot(_bookmark('a', 'hafs:2:5', tagIds: {'x'})),
    );
    expect(
      _bookmark('a', 'hafs:2:5'),
      isNot(_bookmark('a', 'hafs:2:5', categoryId: 'category-b')),
    );
  });

  test('keeps its tags unmodifiable', () {
    final tags = {'x'};
    final bookmark = _bookmark('a', 'hafs:2:5', tagIds: tags);
    tags.add('y');

    expect(bookmark.tagIds, {'x'});
    expect(() => bookmark.tagIds.add('z'), throwsUnsupportedError);
  });

  group('matches', () {
    final bookmark = _bookmark('a', 'hafs:2:5', tagIds: {'t1', 't2'});
    const names = {'t1': 'tag-alpha', 't2': 'tag-beta'};

    test('everything when nothing is asked', () {
      expect(bookmark.matches(), isTrue);
    });

    test('by category and by tag', () {
      expect(bookmark.matches(categoryId: 'category-a'), isTrue);
      expect(bookmark.matches(categoryId: 'category-b'), isFalse);
      expect(bookmark.matches(tagId: 't2'), isTrue);
      expect(bookmark.matches(tagId: 't3'), isFalse);
      expect(bookmark.matches(categoryId: 'category-a', tagId: 't3'), isFalse);
    });

    test('a query inside a tag name, as typed', () {
      expect(bookmark.matches(query: 'beta', tagNames: names), isTrue);
      expect(bookmark.matches(query: 'BETA', tagNames: names), isFalse);
      expect(bookmark.matches(query: 'gamma', tagNames: names), isFalse);
      expect(bookmark.matches(query: 'beta'), isFalse);
    });
  });

  group('ListOrder', () {
    final first = _bookmark('a', 'hafs:3:1', created: 1);
    final second = _bookmark('b', 'hafs:2:7', created: 2);
    final third = _bookmark('c', 'hafs:2:7', created: 3);
    final warsh = _bookmark('d', 'warsh:1:1', created: 4);

    test('newest puts the latest first', () {
      expect([first, warsh, second, third]..sort(ListOrder.newest.compare), [
        warsh,
        third,
        second,
        first,
      ]);
    });

    test('mushaf orders by riwaya, surah and ayah, then older first', () {
      expect([warsh, third, first, second]..sort(ListOrder.mushaf.compare), [
        second,
        third,
        first,
        warsh,
      ]);
    });

    test('falls back to the id for the same time and ayah', () {
      final twin = _bookmark('e', 'hafs:2:7', created: 2);
      expect(ListOrder.mushaf.compare(second, twin), lessThan(0));
      expect(ListOrder.newest.compare(twin, second), greaterThan(0));
    });
  });

  test('the undo window is thirty seconds', () {
    expect(undoWindow, const Duration(seconds: 30));
  });

  test('the exceptions name what they refer to', () {
    expect('${const ItemNotFound('a')}', 'ItemNotFound(a)');
    expect('${const UndoExpired('a')}', 'UndoExpired(a)');
    expect('${const TagNameTaken('tag-a')}', 'TagNameTaken(tag-a)');
    expect(
      '${AyahAlreadyBookmarked(QuranAddress.parse('hafs:2:5'))}',
      'AyahAlreadyBookmarked(hafs:2:5)',
    );
    expect('${_bookmark('a', 'hafs:2:5')}', 'Bookmark(a, hafs:2:5)');
  });

  test('sameIds compares sets', () {
    expect(sameIds({'a', 'b'}, {'b', 'a'}), isTrue);
    expect(sameIds({'a'}, {'a', 'b'}), isFalse);
    expect(sameIds({'a', 'c'}, {'a', 'b'}), isFalse);
  });
}
