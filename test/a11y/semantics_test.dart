import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';

import '../../testing/fakes/fake_app_settings_repository.dart';
import '../../testing/golden.dart';
import '../../testing/test_app.dart';
import 'a11y_support.dart';

// AX-01 and NF-17 (WCAG 4.1.3): what a screen reader is told, and once.
final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  testWidgets('an alert that appears is spoken: its node is a live region', (
    tester,
  ) async {
    addTearDown(tester.ensureSemantics().dispose);
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        const Scaffold(body: IntegrityAlert(title: 'نص تجريبي')),
      ),
    );

    final data = tester.getSemantics(find.byType(IntegrityAlert));
    expect(data.flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('settings says each group once, not as a heading then a group', (
    tester,
  ) async {
    addTearDown(tester.ensureSemantics().dispose);
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(testApp(router));
    router.go(Routes.settings);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(_l10n.levelLabel), findsOneWidget);
    expect(find.bySemanticsLabel(_l10n.themeLabel), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(_l10n.settingsTitle)),
      matchesSemantics(label: _l10n.settingsTitle, isHeader: true),
    );
  });

  testWidgets('onboarding names the app as its heading', (tester) async {
    addTearDown(tester.ensureSemantics().dispose);
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      testApp(router, settings: FakeAppSettingsRepository()),
    );
    router.go(Routes.onboarding);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel(_l10n.appTitle).first),
      matchesSemantics(label: _l10n.appTitle, isHeader: true),
    );
    await expectAccessible(tester);
  });
}
