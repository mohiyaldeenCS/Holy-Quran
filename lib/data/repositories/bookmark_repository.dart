import 'package:flutter/foundation.dart';

import 'package:holyquran/data/services/daos/bookmark_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

/// The user's bookmarks (`UD-01` to `UD-03`, `UD-07`, `SR-08`). Listeners
/// hear of every stored change.
abstract class BookmarkRepository extends ChangeNotifier {
  /// Bookmarks [ayah] in [categoryId]. An ayah that has a bookmark keeps
  /// that one, put in [categoryId]. Throws an [ArgumentError] when [ayah] is
  /// a word address.
  Future<Result<Bookmark>> add(QuranAddress ayah, String categoryId);

  /// The live bookmark of [ayah], or null. Throws an [ArgumentError] when it
  /// is a word address.
  Future<Result<Bookmark?>> bookmarkAt(QuranAddress ayah);

  /// The ayat that have a live bookmark, for the margin marks (`UD-05`).
  Future<Result<Set<QuranAddress>>> bookmarkedAyat();

  Future<Result<void>> setCategory(String id, String categoryId);

  /// Makes [tagIds] the tags of bookmark [id].
  Future<Result<void>> setTags(String id, Set<String> tagIds);

  /// Marks bookmark [id] deleted; [restore] undoes it within [undoWindow].
  Future<Result<void>> delete(String id);

  /// Fails with [UndoExpired] after [undoWindow], and with
  /// [AyahAlreadyBookmarked] when its ayah has been bookmarked since.
  Future<Result<void>> restore(String id);

  /// The live bookmarks in [order], in [categoryId] and tagged [tagId] when
  /// they are given, with a tag whose name contains [query] when it is not
  /// empty.
  Future<Result<List<Bookmark>>> list({
    ListOrder order = ListOrder.newest,
    String? categoryId,
    String? tagId,
    String query = '',
  });
}

/// [BookmarkRepository] over the user database.
final class LocalBookmarkRepository extends BookmarkRepository {
  LocalBookmarkRepository(this._dao, {this._now = _utcMilliseconds});

  final BookmarkDao _dao;
  final int Function() _now;

  static int _utcMilliseconds() => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<Result<Bookmark>> add(QuranAddress ayah, String categoryId) {
    _checkAyah(ayah);
    return _change(() async {
      final row = await _dao.place(ayah.toString(), categoryId, at: _now());
      return _bookmark(row, await _tagsOf(row.id))!;
    });
  }

  @override
  Future<Result<Bookmark?>> bookmarkAt(QuranAddress ayah) {
    _checkAyah(ayah);
    return _read(() async {
      final row = await _dao.liveAt(ayah.toString());
      return row == null ? null : _bookmark(row, await _tagsOf(row.id));
    });
  }

  @override
  Future<Result<Set<QuranAddress>>> bookmarkedAyat() => _read(
    () async => {for (final row in await _dao.live()) ?_ayah(row.address)},
  );

  @override
  Future<Result<void>> setCategory(String id, String categoryId) =>
      _change(() async {
        if (!await _dao.writeCategory(id, categoryId, at: _now())) {
          throw ItemNotFound(id);
        }
      });

  @override
  Future<Result<void>> setTags(String id, Set<String> tagIds) =>
      _change(() async {
        if (!await _dao.writeTags(id, tagIds, at: _now())) {
          throw ItemNotFound(id);
        }
      });

  @override
  Future<Result<void>> delete(String id) => _change(() async {
    if (!await _dao.markDeleted(id, at: _now())) throw ItemNotFound(id);
  });

  @override
  Future<Result<void>> restore(String id) async {
    final BookmarkRow? row;
    switch (await _read(() => _dao.byId(id))) {
      case Ok(:final value):
        row = value;
      case Failure(:final error):
        return Failure(error);
    }
    if (row != null && !row.deleted) return const Ok(null);
    return _change(() async {
      if (row == null) throw ItemNotFound(id);
      final now = _now();
      if (now - row.updatedAt > undoWindow.inMilliseconds) {
        throw UndoExpired(id);
      }
      if (!await _dao.revive(id, at: now)) {
        throw AyahAlreadyBookmarked(QuranAddress.parse(row.address));
      }
    });
  }

  @override
  Future<Result<List<Bookmark>>> list({
    ListOrder order = ListOrder.newest,
    String? categoryId,
    String? tagId,
    String query = '',
  }) => _read(() async {
    final tagIds = <String, Set<String>>{};
    final tagNames = <String, String>{};
    for (final (bookmarkId, tag) in await _dao.liveTags()) {
      tagIds.putIfAbsent(bookmarkId, () => {}).add(tag.id);
      tagNames[tag.id] = tag.name;
    }
    return [
      for (final row in await _dao.live())
        if (_bookmark(row, tagIds[row.id] ?? const {}) case final bookmark?
            when bookmark.matches(
              categoryId: categoryId,
              tagId: tagId,
              query: query,
              tagNames: tagNames,
            ))
          bookmark,
    ]..sort(order.compare);
  });

  Future<Set<String>> _tagsOf(String id) async => {
    for (final (_, tag) in await _dao.liveTags(bookmarkId: id)) tag.id,
  };

  static void _checkAyah(QuranAddress ayah) {
    if (ayah.isWord) {
      throw ArgumentError.value(ayah, 'ayah', 'is a word address');
    }
  }

  /// A stored address that is not a canonical ayah address reads as no
  /// bookmark.
  static QuranAddress? _ayah(String stored) {
    final parsed = QuranAddress.tryParse(stored);
    return parsed == null || parsed.isWord ? null : parsed;
  }

  static Bookmark? _bookmark(BookmarkRow row, Set<String> tagIds) {
    final ayah = _ayah(row.address);
    if (ayah == null) return null;
    return Bookmark(
      id: row.id,
      address: ayah,
      categoryId: row.categoryId,
      tagIds: tagIds,
      createdAt: _time(row.createdAt),
      updatedAt: _time(row.updatedAt),
    );
  }

  static DateTime _time(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  static Future<Result<T>> _read<T>(Future<T> Function() read) async {
    try {
      return Ok(await read());
    } on Exception catch (error) {
      return Failure(error);
    }
  }

  Future<Result<T>> _change<T>(Future<T> Function() change) async {
    final result = await _read(change);
    if (result is Ok<T>) notifyListeners();
    return result;
  }
}
