import 'package:drift/drift.dart';

import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/data/services/user_tables.dart';
import 'package:holyquran/utils/ids.dart';

part 'bookmark_dao.g.dart';

/// Bookmarks and their tags (`UD-01`, `UD-02`). A deletion only sets the
/// tombstone (PRD §10.6).
@DriftAccessor(tables: [Bookmark, BookmarkTag, Tag])
class BookmarkDao extends DatabaseAccessor<UserDatabase>
    with _$BookmarkDaoMixin {
  BookmarkDao(super.attachedDatabase);

  Future<List<BookmarkRow>> live() =>
      (select(bookmark)..where((b) => b.deleted.not())).get();

  /// The bookmark [id], deleted or not.
  Future<BookmarkRow?> byId(String id) =>
      (select(bookmark)..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<BookmarkRow?> liveAt(String address) =>
      (select(bookmark)
            ..where((b) => b.address.equals(address) & b.deleted.not())
            ..orderBy([(b) => OrderingTerm.desc(b.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  /// The live bookmark at [address], put in [categoryId]; a new one when
  /// there is none, so an ayah has one live bookmark.
  Future<BookmarkRow> place(
    String address,
    String categoryId, {
    required int at,
  }) => transaction(() async {
    final existing = await liveAt(address);
    if (existing == null) {
      final row = BookmarkRow(
        id: newId(),
        updatedAt: at,
        deleted: false,
        address: address,
        categoryId: categoryId,
        createdAt: at,
      );
      await into(bookmark).insert(row);
      return row;
    }
    if (existing.categoryId == categoryId) return existing;
    final changed = existing.copyWith(categoryId: categoryId, updatedAt: at);
    await update(bookmark).replace(changed);
    return changed;
  });

  /// Whether a live bookmark [id] was put in [categoryId].
  Future<bool> writeCategory(
    String id,
    String categoryId, {
    required int at,
  }) async =>
      await _whereLive(id).write(
        BookmarkCompanion(categoryId: Value(categoryId), updatedAt: Value(at)),
      ) >
      0;

  /// Whether a live bookmark [id] was marked deleted.
  Future<bool> markDeleted(String id, {required int at}) async =>
      await _whereLive(id).write(
        BookmarkCompanion(deleted: const Value(true), updatedAt: Value(at)),
      ) >
      0;

  /// Clears the tombstone of [id] unless its ayah has another live
  /// bookmark; whether it did.
  Future<bool> revive(String id, {required int at}) => transaction(() async {
    final row = await byId(id);
    if (row == null) return false;
    final other = await liveAt(row.address);
    if (other != null && other.id != id) return false;
    await update(bookmark).replace(row.copyWith(deleted: false, updatedAt: at));
    return true;
  });

  /// The live tags of live and deleted bookmarks, or of [bookmarkId] alone,
  /// as (bookmark id, tag) pairs.
  Future<List<(String, TagRow)>> liveTags({String? bookmarkId}) async {
    final query = select(bookmarkTag).join([
      innerJoin(tag, tag.id.equalsExp(bookmarkTag.tagId)),
    ])..where(bookmarkTag.deleted.not() & tag.deleted.not());
    if (bookmarkId != null) {
      query.where(bookmarkTag.bookmarkId.equals(bookmarkId));
    }
    return [
      for (final row in await query.get())
        (row.readTable(bookmarkTag).bookmarkId, row.readTable(tag)),
    ];
  }

  /// Makes [tagIds] the live tags of the live bookmark [id]: pairs are added
  /// or revived, and removed ones marked deleted. A pair with a deleted tag
  /// is left as it is, so restoring the tag brings it back. Whether the
  /// bookmark was live.
  Future<bool> writeTags(String id, Set<String> tagIds, {required int at}) =>
      transaction(() async {
        if ((await byId(id))?.deleted ?? true) return false;
        final pairs = await (select(
          bookmarkTag,
        )..where((p) => p.bookmarkId.equals(id))).get();
        final deletedTags = {
          for (final row in await (select(tag)..where((t) => t.deleted)).get())
            row.id,
        };
        final stored = {for (final pair in pairs) pair.tagId: pair};
        for (final tagId in tagIds) {
          final pair = stored[tagId];
          if (pair == null) {
            await into(bookmarkTag).insert(
              BookmarkTagCompanion.insert(
                bookmarkId: id,
                tagId: tagId,
                updatedAt: at,
              ),
            );
          } else if (pair.deleted) {
            await update(
              bookmarkTag,
            ).replace(pair.copyWith(deleted: false, updatedAt: at));
          }
        }
        for (final pair in pairs) {
          if (!pair.deleted &&
              !tagIds.contains(pair.tagId) &&
              !deletedTags.contains(pair.tagId)) {
            await update(
              bookmarkTag,
            ).replace(pair.copyWith(deleted: true, updatedAt: at));
          }
        }
        return true;
      });

  UpdateStatement<$BookmarkTable, BookmarkRow> _whereLive(String id) =>
      update(bookmark)..where((b) => b.id.equals(id) & b.deleted.not());
}
