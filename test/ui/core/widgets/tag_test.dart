import 'dart:math' as math;

import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';

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

Tag _tag({
  TagShape shape = TagShape.circle,
  bool selected = false,
  String? label,
  VoidCallback? onPressed,
}) => Tag(
  label: label ?? _l10n.tagMemorise,
  shape: shape,
  color: _colors.primary,
  selected: selected,
  onPressed: onPressed ?? () {},
);

/// The tag's drawn face: the box with the line border or the fill.
Finder _face() => find
    .descendant(of: find.byType(Tag), matching: find.byType(Container))
    .first;

BoxDecoration _faceDecoration(WidgetTester tester) =>
    tester.widget<Container>(_face()).decoration! as BoxDecoration;

/// The shape's box, 10 by 10.
Finder _dot() => find.descendant(
  of: find.byType(Tag),
  matching: find.byWidgetPredicate(
    (widget) => widget is SizedBox && widget.width == 10,
  ),
);

BoxDecoration _dotDecoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(of: _dot(), matching: find.byType(DecoratedBox)),
            )
            .decoration
        as BoxDecoration;

Text _label(WidgetTester tester) => tester.widget<Text>(
  find.descendant(of: find.byType(Tag), matching: find.byType(Text)),
);

bool _ringDrawn(WidgetTester tester) =>
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

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets('a 40 high pill, 1 px line border on surface, 15/500 ink', (
    tester,
  ) async {
    await _pump(tester, _tag());
    expect(tester.getSize(_face()).height, 40);
    final face = _faceDecoration(tester);
    expect(face.color, _colors.surface);
    expect(face.borderRadius, BorderRadius.circular(AppRadius.radiusFull));
    expect(face.border, Border.all(color: _colors.line));
    final style = _label(tester).style!;
    expect(style.fontSize, 15);
    expect(style.fontWeight, FontWeight.w500);
    expect(style.color, _colors.ink);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('selected: primary-soft, no visible border, 600, a check mark', (
    tester,
  ) async {
    await _pump(tester, _tag(selected: true));
    final face = _faceDecoration(tester);
    expect(face.color, _colors.primarySoft);
    final border = face.border! as Border;
    expect(border.top.style, BorderStyle.none);
    expect(border.top.width, 1);
    expect(tester.getSize(_face()).height, 40);
    final style = _label(tester).style!;
    expect(style.fontWeight, FontWeight.w600);
    expect(style.color, _colors.onPrimarySoft);
    final check = tester.widget<Icon>(find.byType(Icon));
    expect(check.name, IconName.check);
    expect(check.size, 16);
    expect(check.color, _colors.onPrimarySoft);
  });

  testWidgets('right to left: check, shape, label, 8 apart, padded 16', (
    tester,
  ) async {
    await _pump(tester, _tag(selected: true));
    final face = tester.getRect(_face());
    final check = tester.getRect(find.byType(Icon));
    final dot = tester.getRect(_dot());
    final label = tester.getRect(find.byType(Text));
    // The 1 px border, then the 16 padding.
    expect(face.right - check.right, 1 + AppSpacing.space4);
    expect(check.left - dot.right, AppSpacing.space2);
    expect(dot.left - label.right, AppSpacing.space2);
    expect(label.left - face.left, 1 + AppSpacing.space4);
  });

  testWidgets('draws each shape in the caller colour, 10 by 10', (
    tester,
  ) async {
    for (final shape in TagShape.values) {
      await _pump(tester, _tag(shape: shape));
      expect(tester.getSize(_dot()), const Size.square(10), reason: '$shape');
      final dot = _dotDecoration(tester);
      switch (shape) {
        case TagShape.circle:
          expect(dot.color, _colors.primary);
          expect(dot.borderRadius, BorderRadius.circular(5));
        case TagShape.square:
          expect(dot.color, _colors.primary);
          expect(dot.borderRadius, BorderRadius.circular(2));
        case TagShape.diamond:
          expect(dot.color, _colors.primary);
          expect(dot.borderRadius, isNull);
          final turn = tester.widget<Transform>(
            find.ancestor(of: _dot(), matching: find.byType(Transform)).first,
          );
          expect(
            turn.transform,
            Matrix4.rotationZ(math.pi / 4),
            reason: 'rotate(45deg)',
          );
        case TagShape.ring:
          expect(dot.color, isNull);
          expect(dot.borderRadius, BorderRadius.circular(5));
          expect(dot.border, Border.all(color: _colors.primary, width: 2));
      }
    }
  });

  testWidgets('calls onPressed by tap, across the 48 target, and keyboard', (
    tester,
  ) async {
    var presses = 0;
    await _pump(tester, _tag(onPressed: () => presses++));
    final target = tester.getRect(find.byType(Tag));
    expect(target.height, AppSizes.targetMin);
    await tester.tap(find.byType(Text));
    await tester.tapAt(Offset(target.center.dx, target.top + 1));
    expect(presses, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(presses, 3);
  });

  testWidgets('reads as one labelled button with its selected state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tag(selected: true),
          _tag(label: _l10n.tagReview, shape: TagShape.square),
        ],
      ),
    );
    expect(
      tester.getSemantics(find.byType(Tag).first),
      matchesSemantics(
        label: _l10n.tagMemorise,
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byType(Tag).last),
      matchesSemantics(
        label: _l10n.tagReview,
        isButton: true,
        hasSelectedState: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    // Not a switch: neither has a toggled state.
    for (final tag in [find.byType(Tag).first, find.byType(Tag).last]) {
      expect(
        tester.getSemantics(tag),
        isNot(isSemantics(hasToggledState: true)),
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, _tag());
    expect(_ringDrawn(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester), isTrue);
    expect(
      tester.widget<FocusRing>(find.byType(FocusRing)).radius,
      BorderRadius.circular(AppRadius.radiusFull),
    );

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(_ringDrawn(tester), isFalse);
  });

  testWidgets('wraps instead of clipping at 200% text on 360 wide', (
    tester,
  ) async {
    await _pump(
      tester,
      Wrap(
        children: [
          for (final shape in TagShape.values)
            _tag(
              shape: shape,
              selected: shape == TagShape.circle,
              label: '${_l10n.tagImportant} ${_l10n.mainNavigationLabel}',
            ),
        ],
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    for (final element in find.byType(Tag).evaluate()) {
      final size = (element.renderObject! as RenderBox).size;
      expect(size.width, lessThanOrEqualTo(360));
      expect(size.height, greaterThanOrEqualTo(AppSizes.targetMin));
    }
  });
}
