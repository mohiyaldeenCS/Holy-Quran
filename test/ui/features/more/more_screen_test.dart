import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/feature_routes.dart';
import 'package:holyquran/ui/core/gallery/gallery_screen.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/features/more/views/more_screen.dart';
import 'package:holyquran/ui/features/settings/views/settings_screen.dart';
import 'package:holyquran/ui/features/sources/views/sources_screen.dart';

import '../../../../testing/test_app.dart';
import '../settings/text_fit.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<GoRouter> _pumpMore(
  WidgetTester tester, {
  List<FeatureRoutes>? features,
}) async {
  final router = createRouter(features: features);
  await tester.pumpWidget(testApp(router));
  router.go(Routes.more);
  await tester.pumpAndSettle();
  return router;
}

Finder _entry(String label) => find.widgetWithText(Button, label);

void main() {
  testWidgets('lists its entries, and no sign-in', (tester) async {
    await _pumpMore(tester);

    final labels = [
      for (final button in tester.widgetList<Button>(find.byType(Button)))
        button.label,
    ];
    expect(labels, [
      _l10n.resourceManagerTitle,
      _l10n.settingsTitle,
      _l10n.sourcesTitle,
      if (kDebugMode) _l10n.galleryTitle,
    ]);
    expect(find.bySemanticsLabel(_l10n.tabMore), findsAtLeastNWidgets(1));
  });

  testWidgets('opens the sources and licences', (tester) async {
    final router = await _pumpMore(tester);

    await tester.tap(_entry(_l10n.sourcesTitle));
    await tester.pumpAndSettle();

    expect(find.byType(SourcesScreen), findsOneWidget);
    expect(router.state.uri.path, Routes.sources);
  });

  testWidgets('opens the settings', (tester) async {
    final router = await _pumpMore(tester);

    await tester.tap(_entry(_l10n.settingsTitle));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(router.state.uri.path, Routes.settings);
  });

  for (final (label, path, location) in [
    (_l10n.bookmarksAndNotes, RoutePaths.bookmarks, Routes.bookmarks),
  ]) {
    testWidgets('shows «$label» once its screen has a route (PRD §7.1)', (
      tester,
    ) async {
      await _pumpMore(tester);
      expect(_entry(label), findsNothing);

      final router = await _pumpMore(
        tester,
        features: [...appFeatures, _syntheticScreenAt(path)],
      );
      await tester.tap(_entry(label));
      await tester.pumpAndSettle();

      expect(find.byKey(_syntheticScreen), findsOneWidget);
      expect(router.state.uri.path, location);
    });
  }

  testWidgets('opens the gallery in a debug build', (tester) async {
    await _pumpMore(tester);

    await tester.tap(_entry(_l10n.galleryTitle));
    await tester.pumpAndSettle();

    expect(find.byType(GalleryScreen), findsOneWidget);
  }, skip: !kDebugMode);

  testWidgets('every entry is at least 48 high', (tester) async {
    await _pumpMore(tester);

    for (final button in tester.widgetList<Button>(find.byType(Button))) {
      expect(
        tester.getSize(find.byWidget(button)).height,
        greaterThanOrEqualTo(AppSizes.targetMin),
      );
    }
  });

  testWidgets('fits a small phone at 200% text', (tester) async {
    usePhoneAtDoubleText(tester);
    await _pumpMore(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(MoreScreen), findsOneWidget);
    for (final label in [_l10n.tabMore, _l10n.settingsTitle]) {
      final text = find.descendant(
        of: find.byType(MoreScreen),
        matching: find.text(label),
      );
      await tester.scrollUntilVisible(text, 100);
      expectWordsFit(tester, text);
    }
  });

  testWidgets('makes no network call', (tester) async {
    final previous = HttpOverrides.current;
    final overrides = _CountingHttpOverrides();
    HttpOverrides.global = overrides;
    addTearDown(() => HttpOverrides.global = previous);

    await _pumpMore(tester);
    await tester.tap(_entry(_l10n.settingsTitle));
    await tester.pumpAndSettle();

    expect(overrides.clients, 0);
  });
}

const _syntheticScreen = Key('synthetic screen');

FeatureRoutes _syntheticScreenAt(String path) => FeatureRoutes(
  tabChildren: {
    ShellTab.more: [
      GoRoute(
        path: path,
        builder: (context, state) => const SizedBox(key: _syntheticScreen),
      ),
    ],
  },
);

final class _CountingHttpOverrides extends HttpOverrides {
  int clients = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    return super.createHttpClient(context);
  }
}
