import 'dart:io';

import 'package:flutter/material.dart' hide Switch;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/switch.dart';
import 'package:holyquran/ui/features/more/views/more_screen.dart';
import 'package:holyquran/ui/features/settings/views/settings_screen.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../testing/fakes/fake_pack_install_repository.dart';
import 'text_fit.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<GoRouter> _pumpSettings(
  WidgetTester tester,
  FakeAppSettingsRepository settings, {
  FakePackInstallRepository? packs,
}) async {
  final router = createRouter();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsRepository>.value(value: settings),
        ListenableProvider<PackInstallRepository>.value(
          value: packs ?? FakePackInstallRepository(),
        ),
      ],
      child: QuranApp(router: router),
    ),
  );
  router.go(Routes.settings);
  await tester.pumpAndSettle();
  return router;
}

Finder _segment(String label) =>
    find.descendant(of: find.byType(LevelSwitch), matching: find.text(label));

void main() {
  testWidgets('shows the level, the theme and the follow-system switch', (
    tester,
  ) async {
    await _pumpSettings(tester, FakeAppSettingsRepository());

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text(_l10n.settingsTitle), findsOneWidget);
    for (final label in [
      _l10n.levelSimple,
      _l10n.levelMedium,
      _l10n.levelStudy,
      _l10n.themePaper,
      _l10n.themeNight,
      _l10n.themeSepia,
      _l10n.themeContrast,
    ]) {
      expect(_segment(label), findsOneWidget, reason: label);
    }
    expect(find.widgetWithText(Switch, _l10n.followSystemDark), findsOneWidget);
  });

  testWidgets('names its controls and headings for a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpSettings(tester, FakeAppSettingsRepository());

    expect(
      tester.getSemantics(find.bySemanticsLabel(_l10n.back).first),
      isSemantics(isButton: true, hasTapAction: true, label: _l10n.back),
    );
    expect(find.bySemanticsLabel(_l10n.levelLabel), findsAtLeastNWidgets(1));
    expect(find.bySemanticsLabel(_l10n.themeLabel), findsAtLeastNWidgets(1));
    expect(
      tester.getSemantics(find.text(_l10n.settingsTitle)),
      isSemantics(isHeader: true, label: _l10n.settingsTitle),
    );
    semantics.dispose();
  });

  testWidgets('a chosen level applies at once and changes nothing else', (
    tester,
  ) async {
    final settings = FakeAppSettingsRepository();
    final packs = FakePackInstallRepository();
    await _pumpSettings(tester, settings, packs: packs);

    await tester.tap(_segment(_l10n.levelStudy));
    await tester.pump();

    expect(settings.level, UiLevel.study);
    expect(
      tester.element(find.byType(SettingsScreen)).read<UiLevel>(),
      UiLevel.study,
    );
    expect(settings.themePreference, const ThemePreference());
    expect(settings.levelChosen, isFalse);
    expect(packs.calls, isEmpty);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('a chosen theme applies at once', (tester) async {
    final settings = FakeAppSettingsRepository();
    await _pumpSettings(tester, settings);

    await tester.tap(_segment(_l10n.themeSepia));
    await tester.pump();

    expect(settings.themePreference.theme, ReadingTheme.sepia);
    expect(
      tester.element(find.byType(SettingsScreen)).colors,
      same(AppColors.sepia),
    );
  });

  testWidgets('the switch follows the system dark mode (D-053)', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final settings = FakeAppSettingsRepository();
    await _pumpSettings(tester, settings);

    await tester.tap(find.widgetWithText(Switch, _l10n.followSystemDark));
    await tester.pump();

    expect(settings.themePreference.followSystemDark, isTrue);
    expect(
      tester.element(find.byType(SettingsScreen)).colors,
      same(AppColors.night),
    );
  });

  testWidgets('the back button returns to the More hub', (tester) async {
    final router = await _pumpSettings(tester, FakeAppSettingsRepository());

    await tester.tap(find.bySemanticsLabel(_l10n.back).first);
    await tester.pumpAndSettle();

    expect(find.byType(MoreScreen), findsOneWidget);
    expect(router.state.uri.path, Routes.more);
  });

  testWidgets('every hit area is at least 48', (tester) async {
    await _pumpSettings(tester, FakeAppSettingsRepository());

    for (final finder in [
      _segment(_l10n.levelMedium),
      _segment(_l10n.themeContrast),
    ]) {
      final box = tester.getSize(
        find.ancestor(of: finder, matching: find.byType(GestureDetector)).first,
      );
      expect(box.height, greaterThanOrEqualTo(AppSizes.targetMin));
    }
    expect(
      tester.getSize(find.byType(Switch)).height,
      greaterThanOrEqualTo(AppSizes.targetMin),
    );
  });

  testWidgets('fits a small phone at 200% text', (tester) async {
    usePhoneAtDoubleText(tester);
    await _pumpSettings(tester, FakeAppSettingsRepository());

    expect(tester.takeException(), isNull);
    for (final label in [
      _l10n.settingsTitle,
      _l10n.levelLabel,
      _l10n.levelSimple,
      _l10n.levelMedium,
      _l10n.levelStudy,
      _l10n.themeLabel,
      _l10n.themePaper,
      _l10n.themeNight,
      _l10n.themeSepia,
      _l10n.themeContrast,
      _l10n.followSystemDark,
    ]) {
      await tester.scrollUntilVisible(find.text(label), 100);
      expectWordsFit(tester, find.text(label));
    }
  });

  testWidgets('makes no network call', (tester) async {
    final previous = HttpOverrides.current;
    final overrides = _CountingHttpOverrides();
    HttpOverrides.global = overrides;
    addTearDown(() => HttpOverrides.global = previous);

    final settings = FakeAppSettingsRepository();
    await _pumpSettings(tester, settings);
    await tester.tap(_segment(_l10n.levelMedium));
    await tester.tap(_segment(_l10n.themeNight));
    await tester.pumpAndSettle();

    expect(overrides.clients, 0);
  });

  testWidgets('without the settings, the route lands on the home tab', (
    tester,
  ) async {
    final router = createRouter();
    await tester.pumpWidget(QuranApp(router: router));
    router.go(Routes.settings);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsNothing);
    expect(router.state.uri.path, Routes.home);
  });
}

final class _CountingHttpOverrides extends HttpOverrides {
  int clients = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    return super.createHttpClient(context);
  }
}
