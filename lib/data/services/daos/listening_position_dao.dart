import 'package:drift/drift.dart';

import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/data/services/user_tables.dart';
import 'package:holyquran/utils/ids.dart';

part 'listening_position_dao.g.dart';

/// The one listening-position row of this device (D-106).
@DriftAccessor(tables: [ListeningPosition])
class ListeningPositionDao extends DatabaseAccessor<UserDatabase>
    with _$ListeningPositionDaoMixin {
  ListeningPositionDao(super.attachedDatabase);

  /// The stored row, or null when none is stored or it was deleted.
  Future<ListeningPositionRow?> read() async {
    final row = await _row();
    return row == null || row.deleted ? null : row;
  }

  /// Stores the position in the one row, creating it on first use.
  Future<void> write(
    String address,
    String recitationId,
    int offsetMs, {
    required int updatedAt,
  }) => transaction(() async {
    final row = await _row();
    if (row == null) {
      await into(listeningPosition).insert(
        ListeningPositionCompanion.insert(
          id: newId(),
          address: address,
          recitationId: recitationId,
          offsetMs: offsetMs,
          updatedAt: updatedAt,
        ),
      );
      return;
    }
    await update(listeningPosition).replace(
      row.copyWith(
        address: address,
        recitationId: recitationId,
        offsetMs: offsetMs,
        updatedAt: updatedAt,
        deleted: false,
      ),
    );
  });

  Future<ListeningPositionRow?> _row() =>
      (select(listeningPosition)..limit(1)).getSingleOrNull();
}
