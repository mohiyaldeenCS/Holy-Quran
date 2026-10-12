import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/ui/features/onboarding/view_models/setup_step.dart';
import 'package:holyquran/utils/result.dart';

/// The first-run setup: the steps not yet done, one at a time, in order. A
/// choice is stored at once (`LV-02`); [next] completes the current step.
final class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel({required this._settings, required List<SetupStep> steps})
    : _steps = [
        for (final step in steps)
          if (!step.done) step,
      ] {
    _settings.addListener(notifyListeners);
  }

  final AppSettingsRepository _settings;
  final List<SetupStep> _steps;
  int _current = 0;
  bool _completing = false;
  bool _disposed = false;

  /// The step shown, or null once the setup is finished.
  SetupStep? get step => finished ? null : _steps[_current];

  bool get finished => _current >= _steps.length;

  UiLevel get level => _settings.level;

  /// Stored as chosen; a later choice replaces an earlier one.
  Future<Result<void>> selectLevel(UiLevel level) => _settings.setLevel(level);

  /// Completes the current step and moves to the next. A second call while
  /// the step is being completed does nothing.
  Future<Result<void>> next() async {
    final step = this.step;
    if (step == null || _completing) return const Ok(null);
    _completing = true;
    final result = await step.complete();
    _completing = false;
    if (result is Ok && !_disposed) {
      _current++;
      notifyListeners();
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _settings.removeListener(notifyListeners);
    super.dispose();
  }
}
