import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:holyquran/data/services/daos/integrity_log_dao.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/utils/result.dart';

/// One entry of the integrity log. [kind] is `ok`, `missing`, `repairing`
/// or `failed`; [detail] says why a check failed, with hashes, counts and
/// kinds, never pack text.
final class IntegrityLogEntry {
  const IntegrityLogEntry({
    required this.packId,
    required this.packVersion,
    required this.kind,
    required this.detail,
    required this.occurredAt,
  });

  final String packId;

  /// Null when the version could not be read.
  final int? packVersion;
  final String kind;
  final String? detail;
  final DateTime occurredAt;

  @override
  bool operator ==(Object other) =>
      other is IntegrityLogEntry &&
      other.packId == packId &&
      other.packVersion == packVersion &&
      other.kind == kind &&
      other.detail == detail &&
      other.occurredAt == occurredAt;

  @override
  int get hashCode =>
      Object.hash(packId, packVersion, kind, detail, occurredAt);

  @override
  String toString() => 'IntegrityLogEntry($packId, $packVersion, $kind)';
}

/// The log of what pack checks found, kept on this device (PRD §9.5).
/// Listeners hear of every entry stored and every one that failed.
abstract class IntegrityLogRepository extends ChangeNotifier {
  /// Every entry, newest first.
  Future<Result<List<IntegrityLogEntry>>> entries();

  /// Why the last entry could not be stored or the events failed, or null
  /// when every entry since was stored.
  Exception? get lastError;
}

/// [IntegrityLogRepository] over the user database. It stores each event of
/// [events], in order, until it is disposed.
final class LocalIntegrityLogRepository extends IntegrityLogRepository {
  LocalIntegrityLogRepository(this._dao, Stream<PackIntegrityEvent> events) {
    _subscription = events
        .asyncMap(_store)
        .listen(
          null,
          onError: (Object error) {
            _lastError = error is Exception ? error : Exception('$error');
            notifyListeners();
          },
        );
  }

  final IntegrityLogDao _dao;
  late final StreamSubscription<void> _subscription;
  Exception? _lastError;

  @override
  Exception? get lastError => _lastError;

  @override
  Future<Result<List<IntegrityLogEntry>>> entries() async {
    try {
      return Ok([
        for (final row in await _dao.entries())
          IntegrityLogEntry(
            packId: row.packId,
            packVersion: row.packVersion,
            kind: row.kind,
            detail: row.detail,
            occurredAt: DateTime.fromMillisecondsSinceEpoch(
              row.occurredAt,
              isUtc: true,
            ),
          ),
      ]);
    } on Exception catch (error) {
      return Failure(error);
    }
  }

  Future<void> _store(PackIntegrityEvent event) async {
    try {
      await _dao.append(
        packId: event.pack,
        packVersion: event.version,
        kind: _kind(event.state),
        detail: switch (event.state) {
          IntegrityFailed(:final reason) => '$reason',
          _ => null,
        },
        occurredAt: event.at.millisecondsSinceEpoch,
      );
      _lastError = null;
    } on Exception catch (error) {
      _lastError = error;
    }
    notifyListeners();
  }

  static String _kind(PackIntegrity state) => switch (state) {
    IntegrityOk() => 'ok',
    IntegrityMissing() => 'missing',
    IntegrityRepairing() => 'repairing',
    IntegrityFailed() => 'failed',
  };

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
