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

  bool? _followSystemDark;
  var _followWrites = 0;
  var _disposed = false;

  /// Whether the theme follows the system's dark mode, as it will be stored
  /// once the last change is saved.
  bool get followSystemDark =>
      _followSystemDark ?? _settings.themePreference.followSystemDark;

  /// Turns following the system's dark mode the other way from
  /// [followSystemDark], so that quick taps each count. A failed last save
  /// shows the stored choice again.
  Future<Result<void>> toggleFollowSystemDark() async {
    final follow = _followSystemDark = !followSystemDark;
    final write = ++_followWrites;
    notifyListeners();
    final result = await _settings.setFollowSystemDark(follow);
    if (write == _followWrites && !_disposed) {
      _followSystemDark = null;
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
