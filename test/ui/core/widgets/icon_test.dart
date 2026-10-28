import 'package:flutter/material.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

import '../../../../testing/golden.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(goldenApp(ReadingTheme.paper, child));

void main() {
  testWidgets('is icon-size square by default and takes a size', (
    tester,
  ) async {
    await _pump(
      tester,
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(IconName.home, key: ValueKey('default')),
          Icon(IconName.home, size: 28, key: ValueKey('sized')),
        ],
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('default'))),
      const Size.square(AppSizes.iconSize),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('sized'))),
      const Size.square(28),
    );
  });

  testWidgets('strokes line icons with round ends in the icon colour', (
    tester,
  ) async {
    await _pump(
      tester,
      IconTheme(
        data: IconThemeData(color: AppColors.paper.ink),
        child: const Icon(IconName.search),
      ),
    );
    expect(
      find.byType(Icon),
      paints..something((method, arguments) {
        if (method != #drawPath) return false;
        final paint = arguments[1] as Paint;
        return paint.color.toARGB32() == AppColors.paper.ink.toARGB32() &&
            paint.style == PaintingStyle.stroke &&
            paint.strokeWidth == AppSizes.iconStroke &&
            paint.strokeCap == StrokeCap.round &&
            paint.strokeJoin == StrokeJoin.round;
      }),
    );
  });

  testWidgets('fills play and pause, in the colour given', (tester) async {
    await _pump(tester, Icon(IconName.play, color: AppColors.paper.primary));
    expect(
      find.byType(Icon),
      paints..path(color: AppColors.paper.primary, style: PaintingStyle.fill),
    );
  });

  testWidgets('scales the 24 grid to its size', (tester) async {
    await _pump(tester, const Icon(IconName.minus, size: 48));
    expect(
      find.byType(Icon),
      paints
        ..scale(x: 2, y: 2)
        ..path(strokeWidth: AppSizes.iconStroke),
    );
  });

  testWidgets('is not mirrored right to left', (tester) async {
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        const Directionality(
          textDirection: TextDirection.rtl,
          child: Icon(IconName.next, size: 48),
        ),
      ),
    );
    // next is m15 6-6 6 6 6 on the grid: its tip is on the left, the end of
    // an Arabic line. Drawn as is, with no flip, the tip stays there.
    expect(
      find.byType(Icon),
      paints
        ..scale(x: 2, y: 2)
        ..something((method, arguments) {
          if (method != #drawPath) return false;
          final outline = (arguments[0] as Path).computeMetrics().single;
          final start = outline.getTangentForOffset(0)!.position;
          final tip = outline.getTangentForOffset(outline.length / 2)!.position;
          return start == const Offset(15, 6) && tip == const Offset(9, 12);
        }),
    );
  });

  testWidgets('is hidden from screen readers unless labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(IconName.bookmark, key: ValueKey('decorative')),
          Icon(IconName.alert, semanticLabel: 'synthetic label'),
        ],
      ),
    );
    expect(find.bySemanticsLabel('synthetic label'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('synthetic label')),
      isSemantics(label: 'synthetic label', isImage: true),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('decorative')),
        matching: find.byWidgetPredicate(
          (w) => w is ExcludeSemantics && w.excluding,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('decorative')),
        matching: find.byType(Semantics),
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('paints every icon of the set', (tester) async {
    for (final name in IconName.values) {
      await _pump(tester, Icon(name, key: ValueKey(name)));
      expect(find.byType(Icon), paints..path(), reason: name.name);
    }
    expect(IconName.values, hasLength(34));
  });
}
