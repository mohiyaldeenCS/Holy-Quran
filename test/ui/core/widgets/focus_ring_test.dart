import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';

import '../../../../testing/golden.dart';

const _radius = BorderRadius.all(Radius.circular(AppRadius.radiusMd));
const _size = Size(120, 60);

Future<FocusNode> _pumpFocusable(WidgetTester tester) async {
  final node = FocusNode();
  addTearDown(node.dispose);
  await tester.pumpWidget(
    goldenApp(
      ReadingTheme.paper,
      FocusRing(
        radius: _radius,
        child: Focus(
          focusNode: node,
          child: SizedBox.fromSize(size: _size),
        ),
      ),
    ),
  );
  return node;
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
