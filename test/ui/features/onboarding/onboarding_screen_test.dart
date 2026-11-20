import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/startup_redirect.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/lockup.dart';
import 'package:holyquran/ui/core/widgets/radio_row.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:holyquran/ui/features/onboarding/views/onboarding_screen.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../testing/test_app.dart';
import '../settings/text_fit.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<GoRouter> _pumpApp(
  WidgetTester tester,
  FakeAppSettingsRepository settings, {
  String? location,
}) async {
  final router = createRouter();
  await tester.pumpWidget(
    ChangeNotifierProvider<AppSettingsRepository>.value(
      value: settings,
      child: QuranApp(router: router),
    ),
  );
  if (location != null) router.go(location);
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('shows the display mode first, with its one choice, under '
      'the lockup (D-127)', (tester) async {
    await _pumpApp(
      tester,
      FakeAppSettingsRepository(),
      location: Routes.onboarding,
    );

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(Lockup), findsOneWidget);
    expect(find.text(_l10n.setupStepDisplayMode), findsOneWidget);
    expect(find.text(_l10n.setupDisplayModePrompt), findsOneWidget);
    expect(tester.widget<RadioRow>(find.byType(RadioRow)).selected, isTrue);
    expect(find.text(_l10n.displayModeSurah), findsOneWidget);
    expect(find.text(_l10n.setupContinue), findsOneWidget);
    expect(find.bySemanticsLabel(_l10n.setupStepDisplayMode), findsOneWidget);
  });

  testWidgets('passes the three steps, stores the level at once, then goes '
      'home (LV-01, LV-02)', (tester) async {
    final settings = FakeAppSettingsRepository();
    final router = await _pumpApp(
      tester,
      settings,
      location: Routes.onboarding,
    );

    await tester.tap(find.text(_l10n.setupContinue));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.setupLevelPrompt), findsOneWidget);
    expect(
      tester.widget<LevelSwitch>(find.byType(LevelSwitch)).semanticLabel,
      _l10n.levelLabel,
    );
    expect(settings.level, UiLevel.simple);

    await tester.tap(find.text(_l10n.levelMedium));
    await tester.pump();
    expect(settings.level, UiLevel.medium);
    expect(
      tester.element(find.byType(OnboardingScreen)).read<UiLevel>(),
      UiLevel.medium,
    );

    await tester.tap(find.text(_l10n.setupContinue));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.setupStepRecitation), findsOneWidget);
    expect(find.text(_l10n.setupRecitationPrompt), findsOneWidget);
    expect(settings.levelChosen, isFalse);

    await tester.tap(find.text(_l10n.setupFinish));
    await tester.pumpAndSettle();

    expect(settings.levelChosen, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(router.state.uri.path, Routes.home);
  });

  testWidgets('a finished setup goes to the home tab', (tester) async {
    final router = await _pumpApp(
      tester,
      FakeAppSettingsRepository(levelChosen: true),
      location: Routes.onboarding,
    );

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(router.state.uri.path, Routes.home);
  });

  testWidgets('fits a small phone at 200% text', (tester) async {
    usePhoneAtDoubleText(tester);
    await _pumpApp(
      tester,
      FakeAppSettingsRepository(),
      location: Routes.onboarding,
    );

    expect(tester.takeException(), isNull);
    expectWordsFit(tester, find.text(_l10n.displayModeSurah));
    await tester.tap(find.text(_l10n.setupContinue));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final label in [
      _l10n.levelSimple,
      _l10n.levelMedium,
      _l10n.levelStudy,
    ]) {
      expectWordsFit(tester, find.text(label));
    }
  });

  group('the first-run redirect', () {
    Future<GoRouter> pumpRedirecting(
      WidgetTester tester,
      FakeAppSettingsRepository settings, {
      String location = Routes.home,
    }) async {
      final router = GoRouter(
        initialLocation: location,
        redirect: firstRunRedirect,
        routes: [
          for (final path in [Routes.home, Routes.more, Routes.onboarding])
            GoRoute(path: path, builder: (context, state) => const SizedBox()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(testApp(router, settings: settings));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('is off in the app until the setup has its wording', (
      tester,
    ) async {
      final router = await _pumpApp(tester, FakeAppSettingsRepository());

      expect(router.state.uri.path, Routes.home);
    });

    testWidgets('sends a new user to the setup', (tester) async {
      final router = await pumpRedirecting(
        tester,
        FakeAppSettingsRepository(),
        location: Routes.more,
      );

      expect(router.state.uri.path, Routes.onboarding);
    });

    testWidgets('lets a user who finished it in', (tester) async {
      final router = await pumpRedirecting(
        tester,
        FakeAppSettingsRepository(levelChosen: true),
        location: Routes.more,
      );

      expect(router.state.uri.path, Routes.more);
    });
  });
}
