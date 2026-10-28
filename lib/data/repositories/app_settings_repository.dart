import 'package:flutter/foundation.dart';

import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/settings_store.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/utils/result.dart';

/// The app-wide settings: theme (`RD-08`), interface level (`LV-01`), the
/// first-run level choice, opening at the last position (`RD-13`), keeping
/// the screen awake (`RD-16`) and the surah-mode text size (`RD-07`).
/// Listeners hear of every stored change.
abstract class AppSettingsRepository extends ChangeNotifier {
  // RD-13 and RD-16 give no default; these await the owner's answer.
  static const openAtLastPositionDefault = false;
  static const keepScreenAwakeDefault = true;
  static const surahTextScaleDefault = 1.0;

  ThemePreference get themePreference;
  UiLevel get level;

  /// Whether the user has chosen a level in the first-run setup.
  bool get levelChosen;
  bool get openAtLastPosition;
  bool get keepScreenAwake;

  /// The factor applied to surah-mode text; the reader keeps it on its own
  /// ladder of steps.
  double get surahTextScale;

  Future<Result<void>> setTheme(ReadingTheme theme);
  Future<Result<void>> setFollowSystemDark(bool follow);
  Future<Result<void>> setLevel(UiLevel level);
  Future<Result<void>> setLevelChosen(bool chosen);
  Future<Result<void>> setOpenAtLastPosition(bool open);
  Future<Result<void>> setKeepScreenAwake(bool keepAwake);
  Future<Result<void>> setSurahTextScale(double scale);
}

/// [AppSettingsRepository] over the user database's settings.
final class LocalAppSettingsRepository extends AppSettingsRepository {
  LocalAppSettingsRepository._(this._store);

  final SettingsStore _store;

  /// Reads every setting once, so that the values are there before the first
  /// frame (D-105). Throws what the database throws, with its stack trace,
  /// for the start to decide what follows.
  static Future<LocalAppSettingsRepository> load(SettingsDao dao) async =>
      LocalAppSettingsRepository._(await SettingsStore.load(dao));

  static const _theme = 'app.theme';
  static const _followSystemDark = 'app.followSystemDark';
  static const _level = 'app.level';
  static const _levelChosen = 'app.levelChosen';
  static const _openAtLastPosition = 'app.openAtLastPosition';
  static const _keepScreenAwake = 'reader.keepScreenAwake';
  static const _surahTextScale = 'reader.surahTextScale';

  @override
  ThemePreference get themePreference {
    const defaults = ThemePreference();
    return ThemePreference(
      theme: _store.readEnum(_theme, ReadingTheme.values) ?? defaults.theme,
      followSystemDark:
          _store.readBool(_followSystemDark) ?? defaults.followSystemDark,
    );
  }

  @override
  UiLevel get level =>
      _store.readEnum(_level, UiLevel.values) ?? UiLevel.initial;

  @override
  bool get levelChosen => _store.readBool(_levelChosen) ?? false;

  @override
  bool get openAtLastPosition =>
      _store.readBool(_openAtLastPosition) ??
      AppSettingsRepository.openAtLastPositionDefault;

  @override
  bool get keepScreenAwake =>
      _store.readBool(_keepScreenAwake) ??
      AppSettingsRepository.keepScreenAwakeDefault;

  @override
  double get surahTextScale =>
      _store.readDouble(_surahTextScale) ??
      AppSettingsRepository.surahTextScaleDefault;

  @override
  Future<Result<void>> setTheme(ReadingTheme theme) =>
      _set(() => _store.writeEnum(_theme, theme));

  @override
  Future<Result<void>> setFollowSystemDark(bool follow) =>
      _set(() => _store.writeBool(_followSystemDark, follow));

  @override
  Future<Result<void>> setLevel(UiLevel level) =>
      _set(() => _store.writeEnum(_level, level));

  @override
  Future<Result<void>> setLevelChosen(bool chosen) =>
      _set(() => _store.writeBool(_levelChosen, chosen));

  @override
  Future<Result<void>> setOpenAtLastPosition(bool open) =>
      _set(() => _store.writeBool(_openAtLastPosition, open));

  @override
  Future<Result<void>> setKeepScreenAwake(bool keepAwake) =>
      _set(() => _store.writeBool(_keepScreenAwake, keepAwake));

  @override
  Future<Result<void>> setSurahTextScale(double scale) =>
      _set(() => _store.writeDouble(_surahTextScale, scale));

  Future<Result<void>> _set(Future<void> Function() write) async {
    try {
      await write();
    } on Exception catch (error) {
      return Failure(error);
    }
    notifyListeners();
    return const Ok(null);
  }
}
