import 'package:drift/drift.dart';

import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/data/services/user_tables.dart';
import 'package:holyquran/utils/ids.dart';

part 'note_dao.g.dart';

/// Notes and their tags (`UD-04`, `UD-02`). A deletion only sets the
/// tombstone (PRD §10.6).
@DriftAccessor(tables: [Note, NoteTag, Tag])
class NoteDao extends DatabaseAccessor<UserDatabase> with _$NoteDaoMixin {
  NoteDao(super.attachedDatabase);

  Future<List<NoteRow>> live() =>
      (select(note)..where((n) => n.deleted.not())).get();

  Future<List<NoteRow>> liveAt(String address) => (select(
    note,
  )..where((n) => n.address.equals(address) & n.deleted.not())).get();

  /// The note [id], deleted or not.
  Future<NoteRow?> byId(String id) =>
      (select(note)..where((n) => n.id.equals(id))).getSingleOrNull();

  /// Stores a new note with [tagIds].
  Future<NoteRow> add(
    String address,
    String body, {
    required String? categoryId,
    required Set<String> tagIds,
    required int at,
  }) => transaction(() async {
    final row = NoteRow(
      id: newId(),
      updatedAt: at,
      deleted: false,
      address: address,
      body: body,
      categoryId: categoryId,
      createdAt: at,
    );
    await into(note).insert(row);
    await _writeTags(row.id, tagIds, at);
    return row;
  });

  /// Sets the body, category and tags of the live note [id]; whether it was
  /// live.
  Future<bool> edit(
    String id, {
    required String body,
    required String? categoryId,
    required Set<String> tagIds,
    required int at,
  }) => transaction(() async {
    final changed = await _whereLive(id).write(
      NoteCompanion(
        body: Value(body),
        categoryId: Value(categoryId),
        updatedAt: Value(at),
      ),
    );
    if (changed == 0) return false;
    await _writeTags(id, tagIds, at);
    return true;
  });

  /// Whether a live note [id] was marked deleted.
  Future<bool> markDeleted(String id, {required int at}) async =>
      await _whereLive(
        id,
      ).write(NoteCompanion(deleted: const Value(true), updatedAt: Value(at))) >
      0;

  /// Whether a deleted note [id] got its tombstone cleared.
  Future<bool> revive(String id, {required int at}) async =>
      await (update(note)..where((n) => n.id.equals(id) & n.deleted)).write(
        NoteCompanion(deleted: const Value(false), updatedAt: Value(at)),
      ) >
      0;

  /// The live tags of live and deleted notes, or of [noteId] alone, as
  /// (note id, tag) pairs.
  Future<List<(String, TagRow)>> liveTags({String? noteId}) async {
    final query = select(noteTag).join([
      innerJoin(tag, tag.id.equalsExp(noteTag.tagId)),
    ])..where(noteTag.deleted.not() & tag.deleted.not());
    if (noteId != null) query.where(noteTag.noteId.equals(noteId));
    return [
      for (final row in await query.get())
        (row.readTable(noteTag).noteId, row.readTable(tag)),
    ];
  }

  /// As `BookmarkDao.writeTags`: pairs with a deleted tag are left alone.
  Future<void> _writeTags(String id, Set<String> tagIds, int at) async {
    final pairs = await (select(
      noteTag,
    )..where((p) => p.noteId.equals(id))).get();
    final deletedTags = {
      for (final row in await (select(tag)..where((t) => t.deleted)).get())
        row.id,
    };
    final stored = {for (final pair in pairs) pair.tagId: pair};
    for (final tagId in tagIds) {
      final pair = stored[tagId];
      if (pair == null) {
        await into(noteTag).insert(
          NoteTagCompanion.insert(noteId: id, tagId: tagId, updatedAt: at),
        );
      } else if (pair.deleted) {
        await update(
          noteTag,
        ).replace(pair.copyWith(deleted: false, updatedAt: at));
      }
    }
    for (final pair in pairs) {
      if (!pair.deleted &&
          !tagIds.contains(pair.tagId) &&
          !deletedTags.contains(pair.tagId)) {
        await update(
          noteTag,
        ).replace(pair.copyWith(deleted: true, updatedAt: at));
      }
    }
  }

  UpdateStatement<$NoteTable, NoteRow> _whereLive(String id) =>
      update(note)..where((n) => n.id.equals(id) & n.deleted.not());
}
