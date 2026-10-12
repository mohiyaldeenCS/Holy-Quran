import 'package:drift/drift.dart';

import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/data/services/user_tables.dart';
import 'package:holyquran/utils/ids.dart';

part 'tag_dao.g.dart';

/// Free tags (`UD-02`). A deletion only sets the tombstone (PRD §10.6).
@DriftAccessor(tables: [Tag])
class TagDao extends DatabaseAccessor<UserDatabase> with _$TagDaoMixin {
  TagDao(super.attachedDatabase);

  Future<List<TagRow>> live() =>
      (select(tag)..where((t) => t.deleted.not())).get();

  /// The tag [id], deleted or not.
  Future<TagRow?> byId(String id) =>
      (select(tag)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// The live tags named exactly [name], oldest first.
  Future<List<TagRow>> liveNamed(String name) =>
      (select(tag)
            ..where((t) => t.name.equals(name) & t.deleted.not())
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  /// The oldest live tag named exactly [name], made when there is none.
  Future<TagRow> named(String name, {required int at}) => transaction(() async {
    final existing = await liveNamed(name);
    if (existing.isNotEmpty) return existing.first;
    final row = TagRow(
      id: newId(),
      updatedAt: at,
      deleted: false,
      name: name,
      createdAt: at,
    );
    await into(tag).insert(row);
    return row;
  });

  /// Whether a live tag [id] was renamed.
  Future<bool> rename(String id, String name, {required int at}) async =>
      await _whereLive(
        id,
      ).write(TagCompanion(name: Value(name), updatedAt: Value(at))) >
      0;

  /// Whether a live tag [id] was marked deleted.
  Future<bool> markDeleted(String id, {required int at}) async =>
      await _whereLive(
        id,
      ).write(TagCompanion(deleted: const Value(true), updatedAt: Value(at))) >
      0;

  /// Whether a deleted tag [id] got its tombstone cleared.
  Future<bool> revive(String id, {required int at}) async =>
      await (update(tag)..where((t) => t.id.equals(id) & t.deleted)).write(
        TagCompanion(deleted: const Value(false), updatedAt: Value(at)),
      ) >
      0;

  UpdateStatement<$TagTable, TagRow> _whereLive(String id) =>
      update(tag)..where((t) => t.id.equals(id) & t.deleted.not());
}
