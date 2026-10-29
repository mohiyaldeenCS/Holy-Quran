import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/features/mushaf/view_models/reader_bookmarks.dart';

import '../../../../testing/fakes/fake_bookmark_repository.dart';
import '../../../../testing/fakes/fake_category_repository.dart';

final _ayah = QuranAddress('hafs', 2, 5);

Bookmark _bookmark(QuranAddress at, String category, {int day = 1}) => Bookmark(
  id: 'b-${at.ayah}',
  address: at,
  categoryId: category,
  tagIds: const {},
  createdAt: DateTime.utc(2030, 1, day),
  updatedAt: DateTime.utc(2030, 1, day),
);

void main() {
  late FakeBookmarkRepository store;
  late FakeCategoryRepository categories;
  late ReaderBookmarks bookmarks;

  Future<void> open([Iterable<Bookmark> existing = const []]) async {
    store = FakeBookmarkRepository(bookmarks: existing);
    categories = FakeCategoryRepository();
    bookmarks = ReaderBookmarks(bookmarks: store, categories: categories);
    addTearDown(bookmarks.dispose);
    await bookmarks.load();
  }

  test('is unavailable without both repositories', () {
    expect(ReaderBookmarks().available, isFalse);
    expect(
      ReaderBookmarks(bookmarks: FakeBookmarkRepository()).available,
      isFalse,
    );
  });

  test('adds in «حفظ» the first time and shows it at once', () async {
    await open();
    await bookmarks.toggle(_ayah);
    expect(bookmarks.has(_ayah), isTrue);
    expect(bookmarks.ribbons.value, {_ayah: BuiltinCategory.memorise});
    expect(bookmarks.failed, isFalse);
  });

  test('takes the category of the newest bookmark', () async {
    await open([
      _bookmark(QuranAddress('hafs', 2, 7), 'fake-study'),
      _bookmark(QuranAddress('hafs', 2, 8), 'fake-review', day: 5),
    ]);
    await bookmarks.toggle(_ayah);
    expect(bookmarks.ribbons.value[_ayah], BuiltinCategory.review);
  });

  test('two quick taps remove it once and keep the undo', () async {
    await open([_bookmark(_ayah, 'fake-review')]);
    final first = bookmarks.toggle(_ayah);
    final second = bookmarks.toggle(_ayah);
    await Future.wait([first, second]);
    expect(bookmarks.has(_ayah), isFalse);
    expect(bookmarks.ribbons.value, isEmpty);
    expect(bookmarks.canUndoAt(_ayah), isTrue);
    expect(bookmarks.failed, isFalse);
  });

  test('undo puts it back with its own category', () async {
    await open([_bookmark(_ayah, 'fake-study')]);
    await bookmarks.toggle(_ayah);
    await bookmarks.undo();
    expect(bookmarks.ribbons.value, {_ayah: BuiltinCategory.study});
    expect(bookmarks.canUndoAt(_ayah), isFalse);
  });

  testWidgets('the undo goes at the undo window', (tester) async {
    await open([_bookmark(_ayah, 'fake-study')]);
    await bookmarks.toggle(_ayah);
    await tester.pump(undoWindow - const Duration(seconds: 1));
    expect(bookmarks.canUndoAt(_ayah), isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(bookmarks.canUndoAt(_ayah), isFalse);
  });

  test('a restore the store refuses is reported, not ignored', () async {
    await open([_bookmark(_ayah, 'fake-study')]);
    await bookmarks.toggle(_ayah);
    store.failure = const UndoExpired('b-5');
    await bookmarks.undo();
    expect(bookmarks.failed, isTrue);
    expect(bookmarks.has(_ayah), isFalse);
    expect(bookmarks.canUndoAt(_ayah), isFalse);
  });

  test('an add the store refuses is reported', () async {
    await open();
    store.failure = Exception('closed');
    await bookmarks.toggle(_ayah);
    expect(bookmarks.failed, isTrue);
    expect(bookmarks.has(_ayah), isFalse);
  });

  test('the notice clears with the next action that works', () async {
    await open();
    store.failure = Exception('closed');
    await bookmarks.toggle(_ayah);
    store.failure = null;
    await bookmarks.toggle(_ayah);
    expect(bookmarks.failed, isFalse);
    expect(bookmarks.has(_ayah), isTrue);
  });

  test('leaving the ayah clears the undo and the notice', () async {
    await open([_bookmark(_ayah, 'fake-study')]);
    await bookmarks.toggle(_ayah);
    bookmarks.leave();
    expect(bookmarks.canUndoAt(_ayah), isFalse);
  });

  test('categories that fail to load say so, and a later try works', () async {
    store = FakeBookmarkRepository();
    categories = FakeCategoryRepository(failure: Exception('closed'));
    bookmarks = ReaderBookmarks(bookmarks: store, categories: categories);
    addTearDown(bookmarks.dispose);
    await bookmarks.load();

    await bookmarks.toggle(_ayah);
    expect(bookmarks.failed, isTrue);
    expect(bookmarks.has(_ayah), isFalse);

    categories.failure = null;
    await bookmarks.toggle(_ayah);
    expect(bookmarks.failed, isFalse);
    expect(bookmarks.ribbons.value, {_ayah: BuiltinCategory.memorise});
  });

  test('a change in the store shows in the ribbons', () async {
    await open();
    await store.add(_ayah, 'fake-important');
    await Future<void>.delayed(Duration.zero);
    expect(bookmarks.ribbons.value, {_ayah: BuiltinCategory.important});
  });
}
