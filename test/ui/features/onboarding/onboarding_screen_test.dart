import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/recitation_repository.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/startup_redirect.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/lockup.dart';
import 'package:holyquran/ui/core/widgets/radio_row.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:holyquran/ui/features/onboarding/views/onboarding_screen.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../testing/fakes/fake_recitation_repository.dart';
import '../../../../testing/test_app.dart';
import '../settings/text_fit.dart';
import 'onboarding_fixture.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<GoRouter> _pumpApp(
  WidgetTester tester,
  FakeAppSettingsRepository settings, {
  String? location,
  List<CatalogueRecitation> recitations = const [],
}) async {
  final router = createRouter();
  final app = ChangeNotifierProvider<AppSettingsRepository>.value(
    value: settings,
    child: QuranApp(router: router),
  );
  await tester.pumpWidget(
    recitations.isEmpty
        ? app
        : ListenableProvider<RecitationRepository>.value(
            value: FakeRecitationRepository(recitations),
            child: app,
          ),
  );
  if (location != null) router.go(location);
  await tester.pumpAndSettle();
  return router;
}

Future<void> _pass(WidgetTester tester, String button) async {
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
}

List<bool> _chosen(WidgetTester tester) => [
  for (final row in tester.widgetList<RadioRow>(find.byType(RadioRow)))
    row.selected,
];

void main() {
  testWidgets('shows the display mode first, with its one choice, below '
      'the lockup (D-127)', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpApp(
      tester,
      FakeAppSettingsRepository(),
      location: Routes.onboarding,
    );

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(_l10n.setupStepDisplayMode)).dy,
      greaterThan(tester.getBottomLeft(find.byType(Lockup)).dy),
    );
    expect(find.text(_l10n.setupDisplayModePrompt), findsOneWidget);
    expect(find.text(_l10n.displayModeSurah), findsOneWidget);
    expect(_chosen(tester), [true]);
    expect(find.text(_l10n.setupContinue), findsOneWidget);
    expect(
      tester.getSemantics(find.text(_l10n.setupStepDisplayMode)),
      isSemantics(label: _l10n.setupStepDisplayMode, isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('writes each choice in the theme ink', (tester) async {
    final recitations = twoReadyRecitations();
    await _pumpApp(
      tester,
      FakeAppSettingsRepository(),
      location: Routes.onboarding,
      recitations: recitations,
    );
    final ink = tester.element(find.byType(OnboardingScreen)).colors.ink;
    Color? colorOf(String text) =>
        tester.widget<Text>(find.text(text)).style?.color;

    expect(colorOf(_l10n.displayModeSurah), ink);
    await _pass(tester, _l10n.setupContinue);
    await _pass(tester, _l10n.setupContinue);

    for (final recitation in recitations) {
      expect(colorOf(recitation.recitation.reciter), ink);
    }
  });

  testWidgets('passes the three steps, stores the level at once, then goes '
      'home (LV-01, LV-02, D-136 (3))', (tester) async {
    final settings = FakeAppSettingsRepository();
    final recitations = twoReadyRecitations();
    final router = await _pumpApp(
      tester,
      settings,
      location: Routes.onboarding,
      recitations: recitations,
    );

    await _pass(tester, _l10n.setupContinue);
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

    await _pass(tester, _l10n.setupContinue);
    expect(find.text(_l10n.setupStepRecitation), findsOneWidget);
    expect(find.text(_l10n.setupRecitationPrompt), findsOneWidget);
    expect(_chosen(tester), [false, false]);
    await tester.tap(find.text(recitations.last.recitation.reciter));
    await tester.pump();
    expect(_chosen(tester), [false, true]);
    expect(settings.levelChosen, isFalse);

    await _pass(tester, _l10n.setupFinish);

    expect(settings.levelChosen, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(router.state.uri.path, Routes.home);
  });

  testWidgets('with no Ready recitation the level step ends the setup '
      '(D-136 (3))', (tester) async {
    final settings = FakeAppSettingsRepository();
    final router = await _pumpApp(
      tester,
      settings,
      location: Routes.onboarding,
    );

    await _pass(tester, _l10n.setupContinue);
    expect(find.text(_l10n.setupLevelPrompt), findsOneWidget);
    expect(find.text(_l10n.setupContinue), findsNothing);
    await _pass(tester, _l10n.setupFinish);

    expect(settings.levelChosen, isTrue);
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

    testWidgets('stays off in the app until the whole-app tests start past '
        'the setup', (tester) async {
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
