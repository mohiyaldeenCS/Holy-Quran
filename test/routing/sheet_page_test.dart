import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/routing/routes/sheet_page.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/theme/motion.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

const _sheetKey = Key('synthetic sheet');

GoRouter _router() => GoRouter(
  initialLocation: '/start',
  routes: [
    GoRoute(path: '/start', builder: (context, state) => const SizedBox()),
    GoRoute(
      path: '/sheet',
      pageBuilder: (context, state) => SheetPage<void>(
        key: state.pageKey,
        child: const SizedBox(key: _sheetKey, height: 120),
      ),
    ),
  ],
);

Future<ModalBottomSheetRoute<void>> _open(
  WidgetTester tester, {
  ReadingTheme theme = ReadingTheme.paper,
}) async {
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    QuranApp(
      router: router,
      themePreference: ThemePreference(theme: theme),
    ),
  );
  unawaited(router.push<void>('/sheet'));
  await tester.pumpAndSettle();
  return ModalRoute.of(tester.element(find.byKey(_sheetKey)))!
      as ModalBottomSheetRoute<void>;
}

void main() {
  for (final theme in ReadingTheme.values) {
    testWidgets('lies over the scrim of ${theme.name}', (tester) async {
      final route = await _open(tester, theme: theme);

      expect(route.barrierColor, AppColors.byId[theme.name]!.scrim);
      expect(route.isDismissible, isTrue);
      expect(route.isScrollControlled, isTrue);
      final localizations = MaterialLocalizations.of(
        tester.element(find.byKey(_sheetKey)),
      );
      expect(route.barrierLabel, localizations.scrimLabel);
      expect(route.barrierLabel, isNotEmpty);
      expect(
        route.barrierOnTapHint,
        localizations.scrimOnTapHint(localizations.bottomSheetLabel),
      );
    });
  }

  testWidgets('slides in at the normal pace', (tester) async {
    final route = await _open(tester);

    expect(route.transitionDuration, motionNormal);
    expect(route.reverseTransitionDuration, motionNormal);
  });

  testWidgets('appears at once when the system reduces motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final route = await _open(tester);

    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
  });
}
