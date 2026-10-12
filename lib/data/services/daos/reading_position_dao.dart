import 'package:drift/drift.dart';

import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/data/services/user_tables.dart';
import 'package:holyquran/utils/ids.dart';

part 'reading_position_dao.g.dart';

/// The one reading-position row of this device (D-106).
@DriftAccessor(tables: [ReadingPosition])
class ReadingPositionDao extends DatabaseAccessor<UserDatabase>
    with _$ReadingPositionDaoMixin {
  ReadingPositionDao(super.attachedDatabase);

  /// The stored address, or null when none is stored or it was deleted.
  Future<String?> readAddress() async {
    final row = await _row();
    return row == null || row.deleted ? null : row.address;
  }

  /// Stores [address] in the one row, creating it on first use.
  Future<void> writeAddress(String address, {required int updatedAt}) =>
      transaction(() async {
        final row = await _row();
        if (row == null) {
          await into(readingPosition).insert(
            ReadingPositionCompanion.insert(
              id: newId(),
              address: address,
              updatedAt: updatedAt,
            ),
          );
          return;
        }
        await (update(
          readingPosition,
        )..where((r) => r.id.equals(row.id))).write(
          ReadingPositionCompanion(
            address: Value(address),
            updatedAt: Value(updatedAt),
            deleted: const Value(false),
          ),
        );
      });

  Future<ReadingPositionRow?> _row() =>
      (select(readingPosition)..limit(1)).getSingleOrNull();
}
