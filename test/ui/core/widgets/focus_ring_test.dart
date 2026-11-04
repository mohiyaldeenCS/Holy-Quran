import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';

import '../../../../testing/golden.dart';

const _radius = BorderRadius.all(Radius.circular(AppRadius.radiusMd));
const _size = Size(120, 60);

Future<FocusNode> _pumpFocusable(
  WidgetTester tester, {
  ReadingTheme theme = ReadingTheme.paper,
  Widget Function(Widget child)? ring,
}) async {
  final node = FocusNode();
  addTearDown(node.dispose);
  final child = Focus(
    focusNode: node,
    child: SizedBox.fromSize(size: _size),
  );
  await tester.pumpWidget(
    goldenApp(
      theme,
      ring == null ? FocusRing(radius: _radius, child: child) : ring(child),
    ),
  );
  return node;
}

double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void _useStrategy(FocusHighlightStrategy strategy) {
  FocusManager.instance.highlightStrategy = strategy;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

PaintPattern _ring() => paints
  ..rrect(
    rrect: _radius.toRRect(Offset.zero & _size).inflate(1),
    color: AppColors.paper.ground,
    style: PaintingStyle.stroke,
    strokeWidth: 2,
  )
  ..rrect(
    rrect: _radius.toRRect(Offset.zero & _size).inflate(3),
    color: AppColors.paper.focus,
    style: PaintingStyle.stroke,
    strokeWidth: 2,
  );

void main() {
  testWidgets('draws a 2 px focus ring 2 px outside a keyboard-focused child', (
    tester,
  ) async {
    _useStrategy(FocusHighlightStrategy.alwaysTraditional);
    final node = await _pumpFocusable(tester);
    expect(find.byType(FocusRing), isNot(_ring()));

    node.requestFocus();
    await tester.pump();
    expect(find.byType(FocusRing), _ring());

    node.unfocus();
    await tester.pumpAndSettle();
    expect(find.byType(FocusRing), isNot(_ring()));
  });

  // D-171 (1): the gap between the ring and the element is `ground`, so the
  // ring is seen on every surface, the `player` bar and the seek track too:
  // against `player` alone `focus` falls to 1.03:1 in paper and sepia. WCAG
  // 1.4.11 asks 3:1 of the indicator against what it touches, which is the
  // gap, whatever lies beyond it.
  for (final theme in ReadingTheme.values) {
    testWidgets('${theme.name}: a ground gap lies between the ring and the '
        'element, and the ring is 3:1 against it', (tester) async {
      _useStrategy(FocusHighlightStrategy.alwaysTraditional);
      final colors = AppColors.byId[theme.name]!;
      final node = await _pumpFocusable(tester, theme: theme);
      node.requestFocus();
      await tester.pump();
      final element = _radius.toRRect(Offset.zero & _size);
      expect(
        find.byType(FocusRing),
        paints
          ..rrect(
            rrect: element.inflate(1),
            color: colors.ground,
            style: PaintingStyle.stroke,
            strokeWidth: 2,
          )
          ..rrect(
            rrect: element.inflate(3),
            color: colors.focus,
            style: PaintingStyle.stroke,
            strokeWidth: 2,
          ),
      );
      expect(_ratio(colors.focus, colors.ground), greaterThanOrEqualTo(3));
    });
  }

  testWidgets('a ring in lines draws a gap and a ring round each line', (
    tester,
  ) async {
    _useStrategy(FocusHighlightStrategy.alwaysTraditional);
    const lines = [Rect.fromLTWH(4, 4, 112, 20), Rect.fromLTWH(60, 34, 56, 20)];
    final node = await _pumpFocusable(
      tester,
      ring: (child) => FocusRing.lines(lines: lines, child: child),
    );
    node.requestFocus();
    await tester.pump();
    var pattern = paints;
    for (final line in lines) {
      pattern = pattern
        ..rrect(
          rrect: RRect.fromRectAndRadius(line, Radius.zero).inflate(1),
          color: AppColors.paper.ground,
          strokeWidth: 2,
        );
    }
    for (final line in lines) {
      pattern = pattern
        ..rrect(
          rrect: RRect.fromRectAndRadius(line, Radius.zero).inflate(3),
          color: AppColors.paper.focus,
          strokeWidth: 2,
        );
    }
    expect(find.byType(FocusRing), pattern);
  });

  testWidgets('draws nothing when focus comes from touch', (tester) async {
    _useStrategy(FocusHighlightStrategy.alwaysTouch);
    final node = await _pumpFocusable(tester);
    node.requestFocus();
    await tester.pump();
    expect(node.hasFocus, isTrue);
    expect(find.byType(FocusRing), isNot(_ring()));
  });

  testWidgets('follows the highlight mode as it changes', (tester) async {
    final node = await _pumpFocusable(tester);
    node.requestFocus();
    await tester.pump();

    await tester.tap(find.byType(FocusRing));
    await tester.pump();
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
    expect(find.byType(FocusRing), isNot(_ring()));

    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
    expect(find.byType(FocusRing), _ring());
  });

  testWidgets('takes no layout space', (tester) async {
    await _pumpFocusable(tester);
    expect(tester.getSize(find.byType(FocusRing)), _size);
  });
}
