import 'package:flutter/material.dart' hide Switch;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/switch.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  bool disableAnimations = false,
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
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// A switch that keeps its own value, as a settings screen would.
Widget _live({bool initial = false, String? label}) {
  var value = initial;
  return StatefulBuilder(
    builder: (context, setState) => Switch(
      label: label ?? _l10n.tabListen,
      value: value,
      onChanged: (next) => setState(() => value = next),
    ),
  );
}

Finder _track() => find
    .descendant(of: find.byType(Switch), matching: find.byType(SizedBox))
    .first;

Finder _knob() => find.descendant(
  of: find.byType(AnimatedPositioned),
  matching: find.byType(DecoratedBox),
);

BoxDecoration _decorationOf(WidgetTester tester, Finder finder) =>
    tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;

Finder _trackFace() =>
    find.descendant(of: _track(), matching: find.byType(DecoratedBox)).first;

/// The knob's distance from the track's right edge.
double _knobRight(WidgetTester tester) =>
    tester.getRect(_track()).right - tester.getRect(_knob()).right;

void main() {
  testWidgets('a 56 by 32 track in a row at least 48 high', (tester) async {
    await _pump(tester, _live());
    expect(tester.getSize(_track()), const Size(56, 32));
    expect(tester.getSize(_knob()), const Size.square(24));
    expect(tester.getSize(find.byType(Switch)).height, AppSizes.targetMin);
    expect(
      _decorationOf(tester, _trackFace()).borderRadius,
      BorderRadius.circular(16),
    );
    expect(
      _decorationOf(tester, _knob()).borderRadius,
      BorderRadius.circular(12),
    );
  });

  testWidgets('the label at the start, the track at the end, right to left', (
    tester,
  ) async {
    await _pump(tester, _live());
    final row = tester.getRect(find.byType(Switch));
    final label = tester.getRect(find.text(_l10n.tabListen));
    expect(label.right, row.right);
    expect(tester.getRect(_track()).left, row.left);
    expect(label.left - tester.getRect(_track()).right, AppSpacing.space4);
    final text = tester.widget<Text>(find.text(_l10n.tabListen));
    expect(text.style!.fontSize, 17);
  });

  testWidgets('off: knob on the right on line; on: on the left on primary', (
    tester,
  ) async {
    const colors = AppColors.paper;
    await _pump(tester, _live());
    expect(_knobRight(tester), 4);
    expect(tester.getRect(_knob()).top - tester.getRect(_track()).top, 4);
    expect(_decorationOf(tester, _trackFace()).color, colors.line);
    expect(_decorationOf(tester, _knob()).color, colors.surface);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(_knobRight(tester), 28);
    expect(_decorationOf(tester, _trackFace()).color, colors.primary);
    expect(_decorationOf(tester, _knob()).color, colors.onPrimary);
  });

  testWidgets('the whole row toggles, label included', (tester) async {
    final values = <bool>[];
    await _pump(
      tester,
      Switch(label: _l10n.tabListen, value: false, onChanged: values.add),
    );
    await tester.tap(find.text(_l10n.tabListen));
    await tester.tap(_track());
    final row = tester.getRect(find.byType(Switch));
    await tester.tapAt(row.center);
    expect(values, [true, true, true]);
  });

  testWidgets('toggles from the keyboard', (tester) async {
    final values = <bool>[];
    await _pump(
      tester,
      Switch(label: _l10n.tabListen, value: true, onChanged: values.add),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(values, [false]);
  });

  testWidgets('moves the knob over 200 ms', (tester) async {
    await _pump(tester, _live());
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_knobRight(tester), allOf(greaterThan(4), lessThan(28)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_knobRight(tester), 28);
  });

  testWidgets('does not animate when animations are turned off', (
    tester,
  ) async {
    await _pump(tester, _live(), disableAnimations: true);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(_knobRight(tester), 28);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reads as a labelled toggle with its state', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _live(initial: true));
    expect(
      tester.getSemantics(find.byType(Switch)),
      matchesSemantics(
        label: _l10n.tabListen,
        hasToggledState: true,
        isToggled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(Switch)),
      isSemantics(hasToggledState: true, isToggled: false),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('wraps a long label at 200% text on 360 wide', (tester) async {
    await _pump(
      tester,
      _live(label: '${_l10n.mainNavigationLabel} ${_l10n.appTitle}'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(_track()), const Size(56, 32));
    expect(
      tester.getSize(find.byType(Switch)).height,
      greaterThanOrEqualTo(AppSizes.targetMin),
    );
  });
}
