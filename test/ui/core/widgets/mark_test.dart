import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/mark.dart';

import '../../../../testing/golden.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(goldenApp(ReadingTheme.paper, child));

void main() {
  final appTitle = lookupAppLocalizations(const Locale('ar')).appTitle;

  testWidgets('is an image named after the app', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const Mark());

    expect(
      tester.getSemantics(find.byType(Mark)),
      matchesSemantics(label: appTitle, isImage: true),
    );
    handle.dispose();
  });

  testWidgets('is hidden from screen readers when decorative', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const Mark(decorative: true));

    expect(find.bySemanticsLabel(appTitle), findsNothing);
    handle.dispose();
  });

  testWidgets('is drawn at its size, 48 by default', (tester) async {
    await _pump(tester, const Mark());
    expect(tester.getSize(find.byType(Mark)), const Size.square(48));

    await _pump(tester, const Mark(size: 96, variant: MarkVariant.emerald));
    expect(tester.getSize(find.byType(Mark)), const Size.square(96));
  });

  test('thickens the stroke as it shrinks', () {
    const expected = [
      (size: 200.0, stroke: 2.2),
      (size: 96.0, stroke: 2.2),
      (size: 95.9, stroke: 3.0),
      (size: 64.0, stroke: 3.0),
      (size: 63.9, stroke: 3.6),
      (size: 48.0, stroke: 3.6),
      (size: 47.9, stroke: 5.0),
      (size: 32.0, stroke: 5.0),
      (size: 31.9, stroke: 6.5),
      (size: 24.0, stroke: 6.5),
    ];
    for (final (:size, :stroke) in expected) {
      expect(markStroke(size), stroke, reason: '$size');
    }
  });

  test('drops the dot under 32 and shrinks it from 64', () {
    expect(markDotRadius(24), isNull);
    expect(markDotRadius(31.9), isNull);
    expect(markDotRadius(32), 3.2);
    expect(markDotRadius(63.9), 3.2);
    expect(markDotRadius(64), 2.6);
    expect(markDotRadius(120), 2.6);
  });
}
