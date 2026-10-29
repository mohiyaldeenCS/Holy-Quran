import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/radio_row.dart';

import '../../../../testing/golden.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool selected,
  required VoidCallback onTap,
  String? label,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 640)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      ReadingTheme.paper,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: SizedBox(
            width: 320,
            child: RadioRow(
              selected: selected,
              onTap: onTap,
              label: label,
              child: const Text('نص تجريبي'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('is a radio that taps and stands at least 48 high', (
    tester,
  ) async {
    var taps = 0;
    await _pump(tester, selected: false, onTap: () => taps++);

    await tester.tap(find.byType(RadioRow));

    expect(taps, 1);
    expect(
      tester.getSize(find.byType(RadioRow)).height,
      greaterThanOrEqualTo(AppSizes.targetMin),
    );
  });

  testWidgets('says it is checked, in a group of one choice', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, selected: true, onTap: () {}, label: 'اسم');

    expect(
      tester.getSemantics(find.byType(RadioRow)),
      matchesSemantics(
        label: 'اسم',
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        isFocusable: true,
        hasFocusAction: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('without a label it reads its child', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, selected: false, onTap: () {});

    expect(
      tester.getSemantics(find.byType(RadioRow)).label,
      contains('نص تجريبي'),
    );
    handle.dispose();
  });

  testWidgets('lays out at 200%', (tester) async {
    await _pump(tester, selected: true, onTap: () {}, textScale: 2);

    expect(tester.takeException(), isNull);
  });
}
