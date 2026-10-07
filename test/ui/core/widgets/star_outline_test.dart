import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';

import '../../../../testing/golden.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(goldenApp(ReadingTheme.night, child));

StarOutlinePainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(StarOutline),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as StarOutlinePainter;

void main() {
  testWidgets('is 28 with stroke 5 in ornament by default', (tester) async {
    await _pump(tester, const StarOutline());

    expect(tester.getSize(find.byType(StarOutline)), const Size.square(28));
    final painter = _painter(tester);
    expect(painter.stroke, 5);
    expect(painter.color, AppColors.night.ornament);
    expect(painter.fill, isNull);
  });

  testWidgets('takes a size, stroke and colour', (tester) async {
    await _pump(
      tester,
      StarOutline(size: 44, stroke: 4, color: AppColors.night.accent),
    );

    expect(tester.getSize(find.byType(StarOutline)), const Size.square(44));
    expect(_painter(tester).stroke, 4);
    expect(_painter(tester).color, AppColors.night.accent);
  });

  testWidgets('is hidden from screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const StarOutline());

    expect(
      tester.getSemantics(find.byType(StarOutline)),
      isNot(matchesSemantics(isImage: true)),
    );
    expect(
      find.descendant(
        of: find.byType(StarOutline),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
