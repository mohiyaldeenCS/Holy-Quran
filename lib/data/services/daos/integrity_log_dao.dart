import 'package:drift/drift.dart';

import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/data/services/user_tables.dart';

part 'integrity_log_dao.g.dart';

/// The local integrity log (PRD §9.5).
@DriftAccessor(tables: [IntegrityEvent])
class IntegrityLogDao extends DatabaseAccessor<UserDatabase>
    with _$IntegrityLogDaoMixin {
  IntegrityLogDao(super.attachedDatabase);

  Future<void> append({
    required String packId,
    required int? packVersion,
    required String kind,
    required String? detail,
    required int occurredAt,
  }) => into(integrityEvent).insert(
    IntegrityEventCompanion.insert(
      packId: packId,
      packVersion: Value(packVersion),
      kind: kind,
      detail: Value(detail),
      occurredAt: occurredAt,
    ),
  );

  /// Every entry, newest first.
  Future<List<IntegrityEventRow>> entries() =>
      (select(integrityEvent)..orderBy([
            (e) => OrderingTerm.desc(e.occurredAt),
            (e) => OrderingTerm.desc(e.id),
          ]))
          .get();
}
