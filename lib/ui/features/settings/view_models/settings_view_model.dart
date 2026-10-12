import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/utils/result.dart';

/// The settings screen's state: the interface level (`LV-01`) and the theme
/// with its follow-system choice (`RD-08`), as stored. A change is stored at
/// once and the app follows it without a restart (`LV-02`); a later choice
/// replaces an earlier one, so none is dropped while another is saved.
final class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._settings) {
    _settings.addListener(notifyListeners);
  }

  final AppSettingsRepository _settings;

  UiLevel get level => _settings.level;

  ThemePreference get themePreference => _settings.themePreference;

  Future<Result<void>> selectLevel(UiLevel level) => _settings.setLevel(level);

  Future<Result<void>> selectTheme(ReadingTheme theme) =>
      _settings.setTheme(theme);

  Future<Result<void>> setFollowSystemDark(bool follow) =>
      _settings.setFollowSystemDark(follow);

  @override
  void dispose() {
    _settings.removeListener(notifyListeners);
    super.dispose();
  }
}
