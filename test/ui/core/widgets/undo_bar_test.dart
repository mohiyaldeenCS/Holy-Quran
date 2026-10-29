import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/undo_bar.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(
  WidgetTester tester,
  VoidCallback onUndo, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: SizedBox(
            width: 340,
            child: UndoBar(message: _l10n.itemDeleted, onUndo: onUndo),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the line and the word «تراجع», which undoes', (
    tester,
  ) async {
    var undone = 0;
    await _pump(tester, () => undone++);
    expect(find.text(_l10n.itemDeleted), findsOneWidget);
    await tester.tap(find.text(_l10n.undo));
    expect(undone, 1);
  });

  testWidgets('the undo is at least 48 high, and the bar is announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, () {});
    expect(
      tester.getSize(find.bySemanticsLabel(_l10n.undo)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSemantics(find.text(_l10n.itemDeleted))
          .getSemanticsData()
          .label,
      contains(_l10n.itemDeleted),
    );
    handle.dispose();
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out in ${theme.name} at 200% text', (tester) async {
      await _pump(tester, () {}, theme: theme, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}
