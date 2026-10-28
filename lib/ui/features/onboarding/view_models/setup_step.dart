import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/utils/result.dart';

/// What a step of the first-run setup asks (PRD §15, recommendation 4; O-17).
/// The display mode and the recitation join when their wording exists; each
/// is shown even while it has a single choice (D-127).
enum SetupStepKind { level }

/// One step of the first-run setup.
abstract interface class SetupStep {
  SetupStepKind get kind;

  bool get done;

  /// Records that the user has passed the step.
  Future<Result<void>> complete();
}

/// The interface level, asked once (PRD §7.3, `LV-01`).
final class LevelStep implements SetupStep {
  const LevelStep(this._settings);

  final AppSettingsRepository _settings;

  @override
  SetupStepKind get kind => SetupStepKind.level;

  @override
  bool get done => _settings.levelChosen;

  @override
  Future<Result<void>> complete() => _settings.setLevelChosen(true);
}

/// The steps in the PRD's order: display mode, level, recitation.
List<SetupStep> setupSteps(AppSettingsRepository settings) => [
  LevelStep(settings),
];

/// Whether [steps] leave nothing for the user to do.
bool setupFinished(List<SetupStep> steps) => steps.every((step) => step.done);
