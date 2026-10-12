import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';

/// Integrity held in memory: every pack is [IntegrityMissing] until
/// [states] or [report] say otherwise, and every report is kept in
/// [reports] and added to [events].
final class FakePackIntegrityRepository extends ChangeNotifier
    implements PackIntegrityRepository {
  FakePackIntegrityRepository([Map<String, PackIntegrity> states = const {}])
    : _states = {...states};

  final Map<String, PackIntegrity> _states;
  final _events = StreamController<PackIntegrityEvent>();
  final reports = <PackIntegrityEvent>[];

  @override
  PackIntegrity stateOf(String pack) =>
      _states[pack] ?? const IntegrityMissing();

  @override
  Stream<PackIntegrityEvent> get events => _events.stream;

  @override
  void report(String pack, PackIntegrity state, {int? version}) {
    final event = PackIntegrityEvent(
      pack: pack,
      version: version,
      state: state,
      at: DateTime.utc(2026),
    );
    _states[pack] = state;
    reports.add(event);
    _events.add(event);
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_events.close());
    super.dispose();
  }
}
