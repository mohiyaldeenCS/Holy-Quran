import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';

/// Why the base pack serves no text, as the integrity alert says it (PRD
/// §9.5, D-180): a pack that is not there is not one that failed.
enum BasePackProblem { missing, failed }

/// The problem of the base pack [basePackId] in [integrity], or null while
/// it serves, while it is being repaired, or when the build reads no base
/// pack and so nothing checks one.
BasePackProblem? basePackProblem(
  PackIntegrityRepository? integrity,
  String? basePackId,
) {
  if (integrity == null || basePackId == null) return null;
  return switch (integrity.stateOf(basePackId)) {
    IntegrityMissing() => BasePackProblem.missing,
    IntegrityFailed() => BasePackProblem.failed,
    IntegrityOk() || IntegrityRepairing() => null,
  };
}
