import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/utils/result.dart';

/// What a step of the first-run setup asks, in the PRD's order (PRD §15,
/// recommendation 4; O-17). Each is shown even while it has a single choice
/// (D-127).
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
/// flag (`LV-01`): of the three, only the level has more than one choice.
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

/// The steps in the PRD's order: display mode, level, recitation.
List<SetupStep> setupSteps(AppSettingsRepository settings) => [
  for (final kind in SetupStepKind.values)
    FirstRunStep(settings, kind, last: kind == SetupStepKind.values.last),
];

/// Whether [steps] leave nothing for the user to do.
bool setupFinished(List<SetupStep> steps) => steps.every((step) => step.done);
