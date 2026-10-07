import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/widgets/tab_bar.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:holyquran/ui/features/listen/views/listen_screen.dart';
import 'package:holyquran/ui/features/more/views/more_screen.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:holyquran/ui/features/study/views/study_screen.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

final _tabs = <({String label, String path, Type screen})>[
  (label: _l10n.tabHome, path: Routes.home, screen: HomeScreen),
  (label: _l10n.tabMushaf, path: Routes.mushaf, screen: MushafScreen),
  (label: _l10n.tabListen, path: Routes.listen, screen: ListenScreen),
  (label: _l10n.tabStudy, path: Routes.study, screen: StudyScreen),
  (label: _l10n.tabMore, path: Routes.more, screen: MoreScreen),
];

Finder _tab(String label) =>
    find.descendant(of: find.byType(TabBar), matching: find.text(label));

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  final router = createRouter();
  await tester.pumpWidget(QuranApp(router: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('starts on the home tab', (tester) async {
    final router = await _pumpApp(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(router.state.uri.path, Routes.home);
  });

  testWidgets('shows the five tabs right to left, home rightmost', (
    tester,
  ) async {
    await _pumpApp(tester);

    final xs = [for (final tab in _tabs) tester.getCenter(_tab(tab.label)).dx];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], lessThan(xs[i - 1]), reason: _tabs[i].label);
    }
  });

  testWidgets('each tab opens its screen at its route', (tester) async {
    final router = await _pumpApp(tester);

    for (final tab in _tabs) {
      await tester.tap(_tab(tab.label));
      await tester.pumpAndSettle();

      expect(find.byType(tab.screen), findsOneWidget, reason: tab.label);
      expect(router.state.uri.path, tab.path);
    }
  });

  testWidgets('a branch keeps its screen while another tab is shown', (
    tester,
  ) async {
    final router = await _pumpApp(tester);

    await tester.tap(_tab(_l10n.tabMushaf));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(_tab(_l10n.tabHome));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(MushafScreen, skipOffstage: false), findsOneWidget);
    expect(router.state.uri.path, Routes.home);
  });

  testWidgets('tapping the current tab keeps its screen', (tester) async {
    final router = await _pumpApp(tester);

    await tester.tap(_tab(_l10n.tabHome));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(router.state.uri.path, Routes.home);
  });
}
