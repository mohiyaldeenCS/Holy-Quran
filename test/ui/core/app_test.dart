import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:provider/provider.dart';

import '../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../testing/test_app.dart';

void main() {
  testWidgets('starts in Arabic, right to left', (tester) async {
    await tester.pumpWidget(testApp(createRouter()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomeScreen));
    expect(Localizations.localeOf(context), const Locale('ar'));
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('the window title is the localized app name', (tester) async {
    await tester.pumpWidget(testApp(createRouter()));
    await tester.pumpAndSettle();

    final title = tester.widget<Title>(find.byType(Title)).title;
    expect(title, lookupAppLocalizations(const Locale('ar')).appTitle);
  });

  group('the active theme', () {
    Future<AppColors> activeColors(
      WidgetTester tester, {
      required ReadingTheme theme,
      required bool followSystemDark,
      required Brightness system,
    }) async {
      tester.platformDispatcher.platformBrightnessTestValue = system;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        testApp(
          createRouter(),
          settings: FakeAppSettingsRepository(
            themePreference: ThemePreference(
              theme: theme,
              followSystemDark: followSystemDark,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.element(find.byType(HomeScreen)).colors;
    }

    testWidgets('is paper by default', (tester) async {
      await tester.pumpWidget(testApp(createRouter()));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(HomeScreen)).colors,
        same(AppColors.paper),
      );
    });

    for (final (theme, followSystemDark, system, expected) in [
      (ReadingTheme.paper, true, Brightness.dark, AppColors.night),
      (ReadingTheme.sepia, true, Brightness.dark, AppColors.night),
      (ReadingTheme.contrast, true, Brightness.dark, AppColors.contrast),
      (ReadingTheme.night, true, Brightness.dark, AppColors.night),
      (ReadingTheme.paper, false, Brightness.dark, AppColors.paper),
      (ReadingTheme.sepia, false, Brightness.dark, AppColors.sepia),
      (ReadingTheme.paper, true, Brightness.light, AppColors.paper),
      (ReadingTheme.sepia, true, Brightness.light, AppColors.sepia),
      (ReadingTheme.night, false, Brightness.light, AppColors.night),
      (ReadingTheme.contrast, false, Brightness.light, AppColors.contrast),
    ]) {
      final follow = followSystemDark ? 'following' : 'not following';
      testWidgets('${theme.name}, $follow a ${system.name} system', (
        tester,
      ) async {
        expect(
          await activeColors(
            tester,
            theme: theme,
            followSystemDark: followSystemDark,
            system: system,
          ),
          same(expected),
        );
      });
    }
  });

  group('the system bars', () {
    for (final (theme, icons) in [
      (ReadingTheme.paper, Brightness.dark),
      (ReadingTheme.sepia, Brightness.dark),
      (ReadingTheme.night, Brightness.light),
      (ReadingTheme.contrast, Brightness.light),
    ]) {
      testWidgets('are ground with ${icons.name} icons on ${theme.name}', (
        tester,
      ) async {
        await tester.pumpWidget(
          testApp(
            createRouter(),
            settings: FakeAppSettingsRepository(
              themePreference: ThemePreference(theme: theme),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final style = tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
            )
            .value;
        expect(style.statusBarIconBrightness, icons);
        expect(style.systemNavigationBarIconBrightness, icons);
        expect(
          style.systemNavigationBarColor,
          AppColors.byId[theme.name]!.ground,
        );
      });
    }
  });

  group('with the settings provided', () {
    Future<void> pumpApp(
      WidgetTester tester,
      FakeAppSettingsRepository settings,
    ) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppSettingsRepository>.value(
          value: settings,
          child: QuranApp(router: createRouter()),
        ),
      );
      await tester.pumpAndSettle();
    }

    AppColors colors(WidgetTester tester) =>
        tester.element(find.byType(HomeScreen)).colors;

    UiLevel level(WidgetTester tester) =>
        tester.element(find.byType(HomeScreen)).read<UiLevel>();

    testWidgets('takes the stored theme and level', (tester) async {
      await pumpApp(
        tester,
        FakeAppSettingsRepository(
          themePreference: const ThemePreference(theme: ReadingTheme.sepia),
          level: UiLevel.study,
        ),
      );

      expect(colors(tester), same(AppColors.sepia));
      expect(level(tester), UiLevel.study);
    });

    // An animated change would show a blend of the two themes after one frame.
    testWidgets('applies a change in the next frame, without animation', (
      tester,
    ) async {
      final settings = FakeAppSettingsRepository();
      await pumpApp(tester, settings);

      await settings.setTheme(ReadingTheme.night);
      await settings.setLevel(UiLevel.medium);
      await tester.pump();

      expect(colors(tester), same(AppColors.night));
      expect(level(tester), UiLevel.medium);
    });

    testWidgets('is not rebuilt by a setting it does not apply', (
      tester,
    ) async {
      final settings = FakeAppSettingsRepository();
      await pumpApp(tester, settings);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

      await settings.setKeepScreenAwake(false);
      await settings.setSurahTextScale(1.5);
      await settings.setOpenAtLastPosition(true);
      await tester.pump();

      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)), same(app));
    });

    testWidgets('keeps the choice across a restart', (tester) async {
      final settings = FakeAppSettingsRepository();
      await pumpApp(tester, settings);
      await settings.setTheme(ReadingTheme.contrast);
      await settings.setLevel(UiLevel.study);

      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, settings);

      expect(colors(tester), same(AppColors.contrast));
      expect(level(tester), UiLevel.study);
    });

    for (final (theme, expected) in [
      (ReadingTheme.paper, AppColors.night),
      (ReadingTheme.sepia, AppColors.night),
      (ReadingTheme.contrast, AppColors.contrast),
    ]) {
      testWidgets('follows a dark system from ${theme.name} (D-053)', (
        tester,
      ) async {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final settings = FakeAppSettingsRepository(
          themePreference: ThemePreference(theme: theme),
        );
        await pumpApp(tester, settings);

        await settings.setFollowSystemDark(true);
        await tester.pump();

        expect(colors(tester), same(expected));
      });
    }
  });
}
