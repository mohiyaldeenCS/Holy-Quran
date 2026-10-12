@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/ui/features/settings/view_models/settings_view_model.dart';
import 'package:holyquran/ui/features/settings/views/settings_screen.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../testing/golden.dart';

void main() {
  testWidgets('the settings screen', (tester) async {
    final settings = FakeAppSettingsRepository(
      themePreference: const ThemePreference(
        theme: ReadingTheme.sepia,
        followSystemDark: true,
      ),
      level: UiLevel.medium,
    );
    await expectGoldensInThemes(
      tester,
      'settings_screen',
      (context) => ChangeNotifierProvider(
        create: (context) => SettingsViewModel(settings),
        child: const SettingsScreen(),
      ),
      surfaceSize: const Size(390, 600),
    );
  });
}
