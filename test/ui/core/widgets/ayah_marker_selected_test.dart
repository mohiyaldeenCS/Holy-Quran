import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('a selected marker draws its ring and number in primary', (
    tester,
  ) async {
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        const AyahMarker(number: 2, selected: true),
      ),
    );
    final ring =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(AyahMarker),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(ring.color, isNull, reason: 'selected is not filled');
    expect((ring.border! as Border).top.color, AppColors.paper.primary);
    final digits = tester.widget<Text>(
      find.descendant(of: find.byType(AyahMarker), matching: find.byType(Text)),
    );
    expect(digits.style!.color, AppColors.paper.primary);
  });

  testWidgets('the recited state wins over the selected one', (tester) async {
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        const AyahMarker(number: 2, selected: true, playing: true),
      ),
    );
    final ring =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(AyahMarker),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(ring.color, AppColors.paper.ornament);
  });
}
