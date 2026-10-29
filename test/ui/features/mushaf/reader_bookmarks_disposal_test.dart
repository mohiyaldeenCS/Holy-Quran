import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/features/mushaf/view_models/reader_bookmarks.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_bookmark_repository.dart';
import '../../../../testing/fakes/fake_category_repository.dart';

final _ayah = QuranAddress('hafs', 2, 5);

/// A store whose add and delete finish when the test says so.
final class _Gated extends BookmarkRepository {
  _Gated(this.inner);

  final FakeBookmarkRepository inner;
  final gate = Completer<void>();

  @override
  Future<Result<Bookmark>> add(QuranAddress ayah, String categoryId) async {
    await gate.future;
    return inner.add(ayah, categoryId);
  }

  @override
  Future<Result<void>> delete(String id) async {
    await gate.future;
    return inner.delete(id);
  }

  @override
  Future<Result<void>> restore(String id) async {
    await gate.future;
    return inner.restore(id);
  }

  @override
  Future<Result<Bookmark?>> bookmarkAt(QuranAddress ayah) =>
      inner.bookmarkAt(ayah);

  @override
  Future<Result<Set<QuranAddress>>> bookmarkedAyat() => inner.bookmarkedAyat();

  @override
  Future<Result<void>> setCategory(String id, String categoryId) =>
      inner.setCategory(id, categoryId);

  @override
  Future<Result<void>> setTags(String id, Set<String> tagIds) =>
      inner.setTags(id, tagIds);

  @override
  Future<Result<List<Bookmark>>> list({
    ListOrder order = ListOrder.newest,
    String? categoryId,
    String? tagId,
    String query = '',
  }) => inner.list(
    order: order,
    categoryId: categoryId,
    tagId: tagId,
    query: query,
  );
}

void main() {
  final existing = Bookmark(
    id: 'b-5',
    address: _ayah,
    categoryId: 'fake-study',
    tagIds: const {},
    createdAt: DateTime.utc(2030),
    updatedAt: DateTime.utc(2030),
  );

  Future<(_Gated, ReaderBookmarks)> open(Iterable<Bookmark> bookmarks) async {
    final store = _Gated(FakeBookmarkRepository(bookmarks: bookmarks));
    final reader = ReaderBookmarks(
      bookmarks: store,
      categories: FakeCategoryRepository(),
    );
    await reader.load();
    return (store, reader);
  }

  testWidgets('an add that finishes after dispose changes nothing', (
    tester,
  ) async {
    final (store, reader) = await open(const []);
    final pending = reader.toggle(_ayah);
    reader.dispose();
    store.gate.complete();
    await pending;
    expect(tester.takeException(), isNull);
  });

  testWidgets('a remove that finishes after dispose starts no undo timer', (
    tester,
  ) async {
    final (store, reader) = await open([existing]);
    final pending = reader.toggle(_ayah);
    reader.dispose();
    store.gate.complete();
    await pending;
    expect(tester.takeException(), isNull);
    // A timer left running would fail the test at its end.
  });

  testWidgets('an undo that finishes after dispose changes nothing', (
    tester,
  ) async {
    final (store, reader) = await open([existing]);
    store.gate.complete();
    await reader.toggle(_ayah);
    expect(reader.canUndoAt(_ayah), isTrue);
    final pending = reader.undo();
    reader.dispose();
    await pending;
    expect(tester.takeException(), isNull);
  });
}
