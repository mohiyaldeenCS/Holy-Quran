import 'package:flutter/material.dart' hide Icon, Stepper;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/stepper.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
const _colors = AppColors.paper;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
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
          child: child,
        ),
      ),
    ),
  );
}

/// A stepper that keeps its own value, as a settings screen would.
Widget _live({
  int initial = 7,
  int min = 1,
  int max = 20,
  String? unit,
  String? label,
  List<int>? changes,
}) {
  var value = initial;
  return StatefulBuilder(
    builder: (context, setState) => Stepper(
      label: label ?? _l10n.galleryStepperRepeat,
      value: value,
      min: min,
      max: max,
      unit: unit,
      onChanged: (next) {
        changes?.add(next);
        setState(() => value = next);
      },
    ),
  );
}

Finder _button(IconName icon) => find.ancestor(
  of: find.byWidgetPredicate((widget) => widget is Icon && widget.name == icon),
  matching: find.byType(Container),
);

BoxDecoration _buttonDecoration(WidgetTester tester, IconName icon) =>
    tester.widget<Container>(_button(icon).first).decoration! as BoxDecoration;

Icon _icon(WidgetTester tester, IconName icon) => tester.widget<Icon>(
  find.byWidgetPredicate((widget) => widget is Icon && widget.name == icon),
);

bool _ringDrawn(WidgetTester tester, Finder ring) =>
    tester
        .widget<CustomPaint>(
          find.descendant(of: ring, matching: find.byType(CustomPaint)).first,
        )
        .foregroundPainter !=
    null;

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets('a row at least 56 high: label 16, value 17/700, both ink', (
    tester,
  ) async {
    await _pump(tester, _live());
    expect(tester.getSize(find.byType(Stepper)).height, 56);
    final label = tester.widget<Text>(find.text(_l10n.galleryStepperRepeat));
    expect(label.style!.fontSize, 16);
    expect(label.style!.fontWeight, FontWeight.w400);
    expect(label.style!.color, _colors.ink);
    final value = tester.widget<Text>(find.text('٧'));
    expect(value.style!.fontSize, 17);
    expect(value.style!.fontWeight, FontWeight.w700);
    expect(value.style!.color, _colors.ink);
    expect(value.textAlign, TextAlign.center);
  });

  testWidgets('48 square buttons, radius 14, line-strong on surface, 18 icon', (
    tester,
  ) async {
    await _pump(tester, _live());
    for (final icon in [IconName.minus, IconName.plus]) {
      expect(tester.getSize(_button(icon).first), const Size.square(48));
      final decoration = _buttonDecoration(tester, icon);
      expect(decoration.color, _colors.surface);
      expect(decoration.borderRadius, BorderRadius.circular(14));
      expect(decoration.border, Border.all(color: _colors.lineStrong));
      expect(_icon(tester, icon).size, 18);
      expect(_icon(tester, icon).color, _colors.ink);
    }
  });

  testWidgets('right to left: label, minus, value, plus; 6 apart, 12 gap', (
    tester,
  ) async {
    await _pump(tester, _live());
    final row = tester.getRect(find.byType(Stepper));
    final label = tester.getRect(find.text(_l10n.galleryStepperRepeat));
    final minus = tester.getRect(_button(IconName.minus).first);
    final plus = tester.getRect(_button(IconName.plus).first);
    expect(label.right, row.right);
    expect(plus.left, row.left);
    // The value box is 52 wide at least: the digit is centred in it.
    expect(minus.left - plus.right, 6 + 52 + 6);
    expect(tester.getCenter(find.text('٧')).dx, (minus.left + plus.right) / 2);
    expect(label.left, greaterThanOrEqualTo(minus.right + AppSpacing.space3));
  });

  testWidgets('steps by one and clamps; the button at a bound is disabled', (
    tester,
  ) async {
    final changes = <int>[];
    await _pump(tester, _live(initial: 2, max: 3, changes: changes));
    await tester.tap(_button(IconName.plus).first);
    await tester.pump();
    expect(find.text('٣'), findsOneWidget);
    await tester.tap(_button(IconName.plus).first);
    await tester.pump();
    expect(changes, [3]);
    final plus = _buttonDecoration(tester, IconName.plus);
    expect(plus.border, Border.all(color: _colors.line));
    expect(_icon(tester, IconName.plus).color, _colors.inkDisabled);
    expect(_icon(tester, IconName.minus).color, _colors.ink);

    for (var i = 0; i < 3; i++) {
      await tester.tap(_button(IconName.minus).first);
      await tester.pump();
    }
    expect(changes, [3, 2, 1]);
    expect(find.text('١'), findsOneWidget);
    expect(_icon(tester, IconName.minus).color, _colors.inkDisabled);
  });

  testWidgets('steps from the keyboard', (tester) async {
    final changes = <int>[];
    await _pump(tester, _live(initial: 5, changes: changes));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(changes, [4, 5]);
  });

  testWidgets('moves keyboard focus to the other button at a bound', (
    tester,
  ) async {
    final changes = <int>[];
    final minusRing = find.ancestor(
      of: _button(IconName.minus).first,
      matching: find.byType(FocusRing),
    );
    final plusRing = find.ancestor(
      of: _button(IconName.plus).first,
      matching: find.byType(FocusRing),
    );
    await _pump(tester, _live(initial: 2, max: 3, changes: changes));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester, minusRing), isTrue);

    // Minus reaches the minimum and is disabled: plus takes the focus, and
    // the keyboard goes on from there.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changes, [1]);
    expect(_icon(tester, IconName.minus).color, _colors.inkDisabled);
    expect(_ringDrawn(tester, minusRing), isFalse);
    expect(_ringDrawn(tester, plusRing), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(changes, [1, 2, 3]);

    // Plus reaches the maximum: minus takes the focus.
    expect(_icon(tester, IconName.plus).color, _colors.inkDisabled);
    expect(_ringDrawn(tester, plusRing), isFalse);
    expect(_ringDrawn(tester, minusRing), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changes, [1, 2, 3, 2]);
  });

  testWidgets('writes the unit after the value', (tester) async {
    await _pump(
      tester,
      _live(initial: 3, min: 0, max: 10, unit: _l10n.galleryStepperSeconds),
    );
    final text = _l10n.stepperValueWithUnit('٣', _l10n.galleryStepperSeconds);
    expect(text, '٣ ث');
    expect(find.text(text), findsOneWidget);
  });

  testWidgets('reads as two named buttons and a live value', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _live(initial: 1));
    final label = _l10n.galleryStepperRepeat;
    expect(_l10n.stepperIncrease(label), 'زيادة $label');
    expect(
      tester.getSemantics(find.bySemanticsLabel(_l10n.stepperIncrease(label))),
      matchesSemantics(
        label: _l10n.stepperIncrease(label),
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(_l10n.stepperDecrease(label))),
      matchesSemantics(
        label: _l10n.stepperDecrease(label),
        isButton: true,
        hasEnabledState: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('١')),
      matchesSemantics(label: '١', isLiveRegion: true),
    );
    expect(
      tester.getSemantics(find.text(label)),
      matchesSemantics(label: label),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, _live());
    final ring = find.byType(FocusRing).first;
    expect(_ringDrawn(tester, ring), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester, ring), isTrue);
    expect(tester.widget<FocusRing>(ring).radius, BorderRadius.circular(14));

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(_ringDrawn(tester, ring), isFalse);
  });

  testWidgets('wraps a long label at 200% text on 360 wide', (tester) async {
    await _pump(
      tester,
      _live(
        initial: 10,
        min: 0,
        label: '${_l10n.galleryStepperSilence} ${_l10n.mainNavigationLabel}',
        unit: _l10n.galleryStepperSeconds,
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Stepper)).width, 360);
    expect(tester.getSize(_button(IconName.plus).first), const Size.square(48));
  });
}
