import 'pack_failure.dart';

/// Whether a pack may serve its content in this session.
sealed class PackIntegrity {
  const PackIntegrity();
}

final class IntegrityOk extends PackIntegrity {
  const IntegrityOk();

  @override
  String toString() => 'ok';
}

/// The pack is neither installed nor bundled.
final class IntegrityMissing extends PackIntegrity {
  const IntegrityMissing();

  @override
  String toString() => 'missing';
}

/// The pack is being copied again from the app after a failed check.
final class IntegrityRepairing extends PackIntegrity {
  const IntegrityRepairing();

  @override
  String toString() => 'repairing';
}

/// The pack failed a check and serves nothing.
final class IntegrityFailed extends PackIntegrity {
  const IntegrityFailed(this.reason);

  final PackFailure reason;

  @override
  String toString() => 'failed: $reason';
}

/// A change of a pack's integrity, for the integrity log.
final class PackIntegrityEvent {
  const PackIntegrityEvent({
    required this.pack,
    required this.version,
    required this.state,
    required this.at,
  });

  final String pack;

  /// Null when the version is not known, as for a pack that is missing.
  final int? version;
  final PackIntegrity state;
  final DateTime at;
}
