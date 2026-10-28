import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/utils/result.dart';

/// [AppSettingsRepository] on the defaults, kept in memory and never written
/// anywhere: the settings of a start whose user database cannot be read, so
/// that the Quran can still be read and the user's file stays untouched.
final class InMemoryAppSettingsRepository extends AppSettingsRepository {
  var _themePreference = const ThemePreference();
  var _level = UiLevel.initial;
  var _levelChosen = false;
  var _openAtLastPosition = AppSettingsRepository.openAtLastPositionDefault;
  var _keepScreenAwake = AppSettingsRepository.keepScreenAwakeDefault;
  var _surahTextScale = AppSettingsRepository.surahTextScaleDefault;

  @override
  ThemePreference get themePreference => _themePreference;
  @override
  UiLevel get level => _level;
  @override
  bool get levelChosen => _levelChosen;
  @override
  bool get openAtLastPosition => _openAtLastPosition;
  @override
  bool get keepScreenAwake => _keepScreenAwake;
  @override
  double get surahTextScale => _surahTextScale;

  @override
  Future<Result<void>> setTheme(ReadingTheme theme) =>
      _set(() => _themePreference = _themePreference.copyWith(theme: theme));

  @override
  Future<Result<void>> setFollowSystemDark(bool follow) => _set(
    () =>
        _themePreference = _themePreference.copyWith(followSystemDark: follow),
  );

  @override
  Future<Result<void>> setLevel(UiLevel level) => _set(() => _level = level);

  @override
  Future<Result<void>> setLevelChosen(bool chosen) =>
      _set(() => _levelChosen = chosen);

  @override
  Future<Result<void>> setOpenAtLastPosition(bool open) =>
      _set(() => _openAtLastPosition = open);

  @override
  Future<Result<void>> setKeepScreenAwake(bool keepAwake) =>
      _set(() => _keepScreenAwake = keepAwake);

  @override
  Future<Result<void>> setSurahTextScale(double scale) =>
      _set(() => _surahTextScale = scale);

  Future<Result<void>> _set(void Function() change) async {
    change();
    notifyListeners();
    return const Ok(null);
  }
}
