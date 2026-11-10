import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/base_pack_problem.dart';
import 'package:holyquran/ui/core/widgets/base_pack_alert.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';

import '../../../../testing/golden.dart';

// D-180: a missing base pack has its own words in the integrity alert's form;
// a failed one keeps the words it had.
final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(
  WidgetTester tester,
  BasePackProblem problem, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Scaffold(body: SizedBox(width: 320, child: BasePackAlert(problem))),
    ),
  );
}

void main() {
  testWidgets('a missing pack says it is missing, not that it failed', (
    tester,
  ) async {
    await _pump(tester, BasePackProblem.missing);

    final alert = tester.widget<IntegrityAlert>(find.byType(IntegrityAlert));
    expect(alert.title, _l10n.integrityBaseMissingTitle);
    expect(alert.body, _l10n.integrityBaseMissingBody);
    expect(alert.action, isNull);
    expect(find.text(_l10n.integrityBaseTitle), findsNothing);
    expect(find.text(_l10n.integrityBaseBody), findsNothing);
  });

  testWidgets('a failed pack keeps the failed words', (tester) async {
    await _pump(tester, BasePackProblem.failed);

    final alert = tester.widget<IntegrityAlert>(find.byType(IntegrityAlert));
    expect(alert.title, _l10n.integrityBaseTitle);
    expect(alert.body, _l10n.integrityBaseBody);
    expect(alert.action, isNull);
    expect(find.text(_l10n.integrityBaseMissingTitle), findsNothing);
  });

  test('the two alerts are worded apart', () {
    expect(_l10n.integrityBaseMissingTitle, isNot(_l10n.integrityBaseTitle));
    expect(_l10n.integrityBaseMissingBody, isNot(_l10n.integrityBaseBody));
    expect(_l10n.integrityBaseMissingTitle, isNotEmpty);
    expect(_l10n.integrityBaseMissingBody, isNotEmpty);
  });

  // The alert is one node: its title and body are spoken together.
  for (final (problem, title, body) in [
    (
      BasePackProblem.missing,
      _l10n.integrityBaseMissingTitle,
      _l10n.integrityBaseMissingBody,
    ),
    (BasePackProblem.failed, _l10n.integrityBaseTitle, _l10n.integrityBaseBody),
  ]) {
    testWidgets('a screen reader hears the ${problem.name} alert as a live '
        'region with its title and body', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, problem);

      final node = tester.getSemantics(find.byType(IntegrityAlert));
      expect(node.flagsCollection.isLiveRegion, isTrue);
      expect(node.label, allOf(contains(title), contains(body)));
      expect(node.label.indexOf(title), lessThan(node.label.indexOf(body)));
      handle.dispose();
    });

    for (final theme in ReadingTheme.values) {
      testWidgets('the ${problem.name} alert lays out in ${theme.name} at '
          '200%', (tester) async {
        await _pump(tester, problem, theme: theme, textScale: 2);

        expect(tester.takeException(), isNull);
        expect(find.text(title), findsOneWidget);
      });
    }
  }
}
