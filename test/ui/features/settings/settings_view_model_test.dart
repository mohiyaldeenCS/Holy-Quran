import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/ui/features/settings/view_models/settings_view_model.dart';

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
    await viewModel.setFollowSystemDark(true);

    expect(settings.level, UiLevel.study);
    expect(
      settings.themePreference,
      const ThemePreference(theme: ReadingTheme.sepia, followSystemDark: true),
    );
    expect(viewModel.level, UiLevel.study);
    expect(notified, 3);
  });

  test('a later choice replaces one still being saved', () async {
    final first = viewModel.selectLevel(UiLevel.medium);
    final second = viewModel.selectLevel(UiLevel.study);
    await Future.wait([first, second]);

    expect(settings.level, UiLevel.study);
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
