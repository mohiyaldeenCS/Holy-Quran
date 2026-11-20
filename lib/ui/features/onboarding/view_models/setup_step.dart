import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/utils/result.dart';

/// What a step of the first-run setup asks, in the PRD's order (PRD §15,
/// recommendation 4; O-17). A step is shown even while it has a single
/// choice (D-127); the recitation only once a recitation is `Ready`
/// (D-136 (3)).
enum SetupStepKind { displayMode, level, recitation }

/// One step of the first-run setup.
abstract interface class SetupStep {
  SetupStepKind get kind;

  bool get done;

  /// Records that the user has passed the step.
  Future<Result<void>> complete();
}

/// A step of the one first-run pass. The pass is recorded once, when its
/// last step is passed, so a setup left midway starts again whole. Until the
/// settings have a key of their own, the record is the level's first-run
/// flag (`LV-01`).
final class FirstRunStep implements SetupStep {
  const FirstRunStep(this._settings, this.kind, {required this.last});

  final AppSettingsRepository _settings;

  @override
  final SetupStepKind kind;

  final bool last;

  @override
  bool get done => _settings.levelChosen;

  @override
  Future<Result<void>> complete() async =>
      last ? _settings.setLevelChosen(true) : const Ok(null);
}

/// The steps in the PRD's order: display mode, level, then the recitation
/// when [recitations], the `Ready` ones, are not empty.
List<SetupStep> setupSteps(
  AppSettingsRepository settings, {
  required List<CatalogueRecitation> recitations,
}) {
  final kinds = [
    SetupStepKind.displayMode,
    SetupStepKind.level,
    if (recitations.isNotEmpty) SetupStepKind.recitation,
  ];
  return [
    for (final kind in kinds)
      FirstRunStep(settings, kind, last: kind == kinds.last),
  ];
}

/// Whether [steps] leave nothing for the user to do.
bool setupFinished(List<SetupStep> steps) => steps.every((step) => step.done);
