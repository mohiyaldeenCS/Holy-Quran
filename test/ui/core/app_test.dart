import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';

void main() {
  testWidgets('starts in Arabic, right to left', (tester) async {
    await tester.pumpWidget(QuranApp(router: createRouter()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomeScreen));
    expect(Localizations.localeOf(context), const Locale('ar'));
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('the window title is the localized app name', (tester) async {
    await tester.pumpWidget(QuranApp(router: createRouter()));
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
        QuranApp(
          router: createRouter(),
          themePreference: ThemePreference(
            theme: theme,
            followSystemDark: followSystemDark,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.element(find.byType(HomeScreen)).colors;
    }

    testWidgets('is paper by default', (tester) async {
      await tester.pumpWidget(QuranApp(router: createRouter()));
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
          QuranApp(
            router: createRouter(),
            themePreference: ThemePreference(theme: theme),
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
}
