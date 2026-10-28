import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/small_button.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
final _label = _l10n.resourceDownload;
const _colors = AppColors.paper;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 600)
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
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: child,
          ),
        ),
      ),
    ),
  );
}

final Finder _face = find.descendant(
  of: find.byType(Pressable),
  matching: find.byType(DecoratedBox),
);

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(_face).decoration as BoxDecoration;

TextStyle _style(WidgetTester tester) =>
    tester.widget<Text>(find.text(_label)).style!;

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets('filled: primary, 44 high, radius 14, 15 px at weight 600', (
    tester,
  ) async {
    await _pump(tester, SmallButton(label: _label, onPressed: () {}));
    final decoration = _decoration(tester);
    expect(decoration.color, _colors.primary);
    expect(decoration.border, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(14));
    expect(tester.getSize(_face).height, 44);
    final style = _style(tester);
    expect(style.fontSize, 15);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.color, _colors.onPrimary);
    final text = tester.getRect(find.text(_label));
    final face = tester.getRect(_face);
    expect(face.left, text.left - AppSpacing.space4);
    expect(face.right, text.right + AppSpacing.space4);
  });

  testWidgets('outlined: no fill, a 1.5 line border, ink text', (tester) async {
    await _pump(
      tester,
      SmallButton(label: _label, onPressed: () {}, outlined: true),
    );
    final decoration = _decoration(tester);
    expect(decoration.color, isNull);
    final border = decoration.border! as Border;
    expect(border.top.color, _colors.line);
    expect(border.top.width, 1.5);
    expect(_style(tester).color, _colors.ink);
  });

  testWidgets('acts when tapped anywhere in its 48 target or by keyboard', (
    tester,
  ) async {
    var presses = 0;
    await _pump(tester, SmallButton(label: _label, onPressed: () => presses++));
    expect(
      tester.getSize(find.byType(SmallButton)).height,
      greaterThanOrEqualTo(48),
    );
    final face = tester.getRect(_face);
    await tester.tapAt(face.center);
    await tester.tapAt(face.topCenter - const Offset(0, 1.5));
    expect(presses, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(presses, 3);
  });

  testWidgets('reads as one labelled button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, SmallButton(label: _label, onPressed: () {}));
    final node = tester.getSemantics(find.byType(Pressable));
    expect(
      node,
      matchesSemantics(
        label: _label,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(node.childrenCount, 0);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, SmallButton(label: _label, onPressed: () {}));
    bool ringDrawn() =>
        tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.byType(FocusRing),
                    matching: find.byType(CustomPaint),
                  )
                  .first,
            )
            .foregroundPainter !=
        null;
    expect(ringDrawn(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ringDrawn(), isTrue);
    expect(
      tester.widget<FocusRing>(find.byType(FocusRing)).radius,
      BorderRadius.circular(14),
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(ringDrawn(), isFalse);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out at 200% text in ${theme.name}', (tester) async {
      await _pump(
        tester,
        SmallButton(label: _label, onPressed: () {}, outlined: true),
        theme: theme,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
