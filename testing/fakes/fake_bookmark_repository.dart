import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

/// Bookmarks held in memory for view tests. Every call fails with [failure]
/// when it is set; a restore is never too late, but fails when the ayah has
/// a live bookmark again. Searches look in [tagNames].
final class FakeBookmarkRepository extends BookmarkRepository {
  FakeBookmarkRepository({
    Iterable<Bookmark> bookmarks = const [],
    this.tagNames = const {},
  }) : _live = {for (final bookmark in bookmarks) bookmark.id: bookmark};

  final Map<String, Bookmark> _live;
  final _deleted = <String, Bookmark>{};
  Map<String, String> tagNames;
  Exception? failure;

  /// How many times [delete] was called, whatever it answered.
  int deleteCalls = 0;
  var _next = 0;

  @override
  Future<Result<Bookmark>> add(QuranAddress ayah, String categoryId) async {
    final existing = _at(ayah);
    final time = DateTime.utc(2026).add(Duration(seconds: _next));
    return _change(
      () => Bookmark(
        id: existing?.id ?? 'fake-bookmark-${_next++}',
        address: ayah,
        categoryId: categoryId,
        tagIds: existing?.tagIds ?? const {},
        createdAt: existing?.createdAt ?? time,
        updatedAt: time,
      ),
    );
  }

  @override
  Future<Result<Bookmark?>> bookmarkAt(QuranAddress ayah) async =>
      failure == null ? Ok(_at(ayah)) : Failure(failure!);

  @override
  Future<Result<Set<QuranAddress>>> bookmarkedAyat() async => failure == null
      ? Ok({for (final bookmark in _live.values) bookmark.address})
      : Failure(failure!);

  @override
  Future<Result<void>> setCategory(String id, String categoryId) =>
      _edit(id, (old) => _copy(old, categoryId: categoryId));

  @override
  Future<Result<void>> setTags(String id, Set<String> tagIds) =>
      _edit(id, (old) => _copy(old, tagIds: tagIds));

  @override
  Future<Result<void>> delete(String id) async {
    deleteCalls++;
    if (failure case final failure?) return Failure(failure);
    final bookmark = _live.remove(id);
    if (bookmark == null) return Failure(ItemNotFound(id));
    _deleted[id] = bookmark;
    notifyListeners();
    return const Ok(null);
  }

  @override
  Future<Result<void>> restore(String id) async {
    if (failure case final failure?) return Failure(failure);
    if (_live.containsKey(id)) return const Ok(null);
    final bookmark = _deleted[id];
    if (bookmark == null) return Failure(ItemNotFound(id));
    if (_at(bookmark.address) != null) {
      return Failure(AyahAlreadyBookmarked(bookmark.address));
    }
    _live[id] = _deleted.remove(id)!;
    notifyListeners();
    return const Ok(null);
  }

  @override
  Future<Result<List<Bookmark>>> list({
    ListOrder order = ListOrder.newest,
    String? categoryId,
    String? tagId,
    String query = '',
  }) async {
    if (failure case final failure?) return Failure(failure);
    return Ok(
      [
        for (final bookmark in _live.values)
          if (bookmark.matches(
            categoryId: categoryId,
            tagId: tagId,
            query: query,
            tagNames: tagNames,
          ))
            bookmark,
      ]..sort(order.compare),
    );
  }

  Bookmark? _at(QuranAddress ayah) {
    for (final bookmark in _live.values) {
      if (bookmark.address == ayah) return bookmark;
    }
    return null;
  }

  static Bookmark _copy(
    Bookmark old, {
    String? categoryId,
    Set<String>? tagIds,
  }) => Bookmark(
    id: old.id,
    address: old.address,
    categoryId: categoryId ?? old.categoryId,
    tagIds: tagIds ?? old.tagIds,
    createdAt: old.createdAt,
    updatedAt: old.updatedAt,
  );

  Future<Result<void>> _edit(
    String id,
    Bookmark Function(Bookmark old) edit,
  ) async {
    final old = _live[id];
    if (old == null && failure == null) return Failure(ItemNotFound(id));
    return _change(() => edit(old!));
  }

  Future<Result<Bookmark>> _change(Bookmark Function() change) async {
    if (failure case final failure?) return Failure(failure);
    final bookmark = change();
    _live[bookmark.id] = bookmark;
    notifyListeners();
    return Ok(bookmark);
  }
}
