import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/ui/features/settings/view_models/settings_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';

void main() {
  late FakeAppSettingsRepository settings;
  late SettingsViewModel viewModel;

  setUp(() {
    settings = FakeAppSettingsRepository();
    viewModel = SettingsViewModel(settings);
  });

  tearDown(() => viewModel.dispose());

  test('starts at «بسيط» on paper, not following the system', () {
    expect(viewModel.level, UiLevel.simple);
    expect(viewModel.themePreference, const ThemePreference());
  });

  test('stores each choice and tells its listeners', () async {
    var notified = 0;
    viewModel.addListener(() => notified++);

    await viewModel.selectLevel(UiLevel.study);
    await viewModel.selectTheme(ReadingTheme.sepia);
    await viewModel.toggleFollowSystemDark();

    expect(settings.level, UiLevel.study);
    expect(
      settings.themePreference,
      const ThemePreference(theme: ReadingTheme.sepia, followSystemDark: true),
    );
    expect(viewModel.level, UiLevel.study);
    expect(viewModel.followSystemDark, isTrue);
    // The toggle tells them of the pending choice, the stored one and the
    // pending one cleared.
    expect(notified, 5);
  });

  test('a later choice replaces one still being saved', () async {
    final first = viewModel.selectLevel(UiLevel.medium);
    final second = viewModel.selectLevel(UiLevel.study);
    await Future.wait([first, second]);

    expect(settings.level, UiLevel.study);
  });

  test('two quick toggles of follow-system end where they began, as '
      'stored', () async {
    final database = UserDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final stored = await LocalAppSettingsRepository.load(SettingsDao(database));
    final model = SettingsViewModel(stored);
    addTearDown(model.dispose);

    final first = model.toggleFollowSystemDark();
    expect(model.followSystemDark, isTrue);
    final second = model.toggleFollowSystemDark();
    expect(model.followSystemDark, isFalse);
    await Future.wait([first, second]);

    expect(stored.themePreference.followSystemDark, isFalse);
    expect(model.followSystemDark, isFalse);
  });

  test('a failed save of follow-system shows the stored choice', () async {
    final failing = _FailingFollow();
    final model = SettingsViewModel(failing);
    addTearDown(model.dispose);

    final result = await model.toggleFollowSystemDark();

    expect(result, isA<Failure<void>>());
    expect(model.followSystemDark, isFalse);
  });

  test('changing the level changes no other setting (LV-02)', () async {
    final before = _snapshot(settings);

    await viewModel.selectLevel(UiLevel.medium);

    expect(_snapshot(settings), {...before, 'level': UiLevel.medium});
  });
}

Map<String, Object> _snapshot(FakeAppSettingsRepository settings) => {
  'level': settings.level,
  'theme': settings.themePreference,
  'levelChosen': settings.levelChosen,
  'openAtLastPosition': settings.openAtLastPosition,
  'keepScreenAwake': settings.keepScreenAwake,
  'surahTextScale': settings.surahTextScale,
};

/// Settings whose follow-system save fails, as a full disk would.
final class _FailingFollow extends AppSettingsRepository {
  @override
  ThemePreference get themePreference => const ThemePreference();
  @override
  UiLevel get level => UiLevel.initial;
  @override
  bool get levelChosen => false;
  @override
  bool get openAtLastPosition =>
      AppSettingsRepository.openAtLastPositionDefault;
  @override
  bool get keepScreenAwake => AppSettingsRepository.keepScreenAwakeDefault;
  @override
  double get surahTextScale => AppSettingsRepository.surahTextScaleDefault;

  @override
  Future<Result<void>> setFollowSystemDark(bool follow) async =>
      const Failure(FormatException('synthetic failure'));

  @override
  Future<Result<void>> setTheme(ReadingTheme theme) =>
      throw UnimplementedError();
  @override
  Future<Result<void>> setLevel(UiLevel level) => throw UnimplementedError();
  @override
  Future<Result<void>> setLevelChosen(bool chosen) =>
      throw UnimplementedError();
  @override
  Future<Result<void>> setOpenAtLastPosition(bool open) =>
      throw UnimplementedError();
  @override
  Future<Result<void>> setKeepScreenAwake(bool keepAwake) =>
      throw UnimplementedError();
  @override
  Future<Result<void>> setSurahTextScale(double scale) =>
      throw UnimplementedError();
}
