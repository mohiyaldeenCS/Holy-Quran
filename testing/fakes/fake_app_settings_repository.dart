import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/utils/result.dart';

/// An in-memory [AppSettingsRepository] for view and widget tests. Starts
/// from the given values and notifies on every set.
final class FakeAppSettingsRepository extends AppSettingsRepository {
  FakeAppSettingsRepository({
    this.themePreference = const ThemePreference(),
    this.level = UiLevel.initial,
    this.levelChosen = false,
    this.openAtLastPosition = AppSettingsRepository.openAtLastPositionDefault,
    this.keepScreenAwake = AppSettingsRepository.keepScreenAwakeDefault,
    this.surahTextScale = AppSettingsRepository.surahTextScaleDefault,
  });

  @override
  ThemePreference themePreference;
  @override
  UiLevel level;
  @override
  bool levelChosen;
  @override
  bool openAtLastPosition;
  @override
  bool keepScreenAwake;
  @override
  double surahTextScale;

  @override
  Future<Result<void>> setTheme(ReadingTheme theme) =>
      _set(() => themePreference = themePreference.copyWith(theme: theme));

  @override
  Future<Result<void>> setFollowSystemDark(bool follow) => _set(
    () => themePreference = themePreference.copyWith(followSystemDark: follow),
  );

  @override
  Future<Result<void>> setLevel(UiLevel level) =>
      _set(() => this.level = level);

  @override
  Future<Result<void>> setLevelChosen(bool chosen) =>
      _set(() => levelChosen = chosen);

  @override
  Future<Result<void>> setOpenAtLastPosition(bool open) =>
      _set(() => openAtLastPosition = open);

  @override
  Future<Result<void>> setKeepScreenAwake(bool keepAwake) =>
      _set(() => keepScreenAwake = keepAwake);

  @override
  Future<Result<void>> setSurahTextScale(double scale) =>
      _set(() => surahTextScale = scale);

  Future<Result<void>> _set(void Function() change) async {
    change();
    notifyListeners();
    return const Ok(null);
  }
}
