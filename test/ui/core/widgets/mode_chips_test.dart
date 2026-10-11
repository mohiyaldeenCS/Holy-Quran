import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
const _colors = AppColors.paper;
final _options = [
  _l10n.searchModeWord,
  _l10n.searchModeRoot,
  _l10n.searchModeBare,
  _l10n.searchModeDerived,
  _l10n.searchModeTafsir,
];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  double width = 360,
}) async {
  tester.view
    ..physicalSize = Size(width, 800)
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

Widget _live({int initial = 1, ValueChanged<int>? onChanged}) {
  var selected = initial;
  return StatefulBuilder(
    builder: (context, setState) => ModeChips(
      options: _options,
      selectedIndex: selected,
      onChanged: (index) {
        onChanged?.call(index);
        setState(() => selected = index);
      },
    ),
  );
}

Finder _face(String option) => find
    .ancestor(of: find.text(option), matching: find.byType(Container))
    .first;

BoxDecoration _decoration(WidgetTester tester, String option) =>
    tester.widget<Container>(_face(option)).decoration! as BoxDecoration;

TextStyle _style(WidgetTester tester, String option) =>
    tester.widget<Text>(find.text(option)).style!;

bool _ringDrawn(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(FocusRing),
        matching: find.byType(CustomPaint),
      ),
    )
    .any((paint) => paint.foregroundPainter != null);

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets('a 48 strip of 40 high chips, 8 apart, inset 2 at the ends', (
    tester,
  ) async {
    await _pump(tester, _live());
    final strip = tester.getRect(find.byType(ModeChips));
    expect(strip.height, AppSizes.targetMin);
    final first = tester.getRect(_face(_options[0]));
    final second = tester.getRect(_face(_options[1]));
    expect(first.height, 40);
    expect(first.top - strip.top, 4);
    // Right to left: the first chip is on the right.
    expect(strip.right - first.right, 2);
    expect(first.left - second.right, AppSpacing.space2);
  });

  testWidgets('an unselected chip: surface, line border, 15/500 ink', (
    tester,
  ) async {
    await _pump(tester, _live());
    final face = _decoration(tester, _options[0]);
    expect(face.color, _colors.surface);
    expect(face.border, Border.all(color: _colors.line));
    expect(face.borderRadius, BorderRadius.circular(20));
    final style = _style(tester, _options[0]);
    expect(style.fontSize, 15);
    expect(style.fontWeight, FontWeight.w500);
    expect(style.color, _colors.ink);
    expect(style.height, isNull);
    // The 1 px border, then the 16 padding.
    final rect = tester.getRect(_face(_options[0]));
    final label = tester.getRect(find.text(_options[0]));
    expect(rect.right - label.right, 1 + AppSpacing.space4);
    expect(label.left - rect.left, 1 + AppSpacing.space4);
  });

  testWidgets('the selected chip: primary-soft, 600, a 16 check before it', (
    tester,
  ) async {
    await _pump(tester, _live());
    final face = _decoration(tester, _options[1]);
    expect(face.color, _colors.primarySoft);
    final border = face.border! as Border;
    expect(border.top.style, BorderStyle.none);
    expect(border.top.width, 1);
    final style = _style(tester, _options[1]);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.color, _colors.onPrimarySoft);
    final check = tester.widget<Icon>(find.byType(Icon));
    expect(check.name, IconName.check);
    expect(check.size, 16);
    expect(check.color, _colors.onPrimarySoft);
    expect(find.byType(Icon), findsOneWidget);
    final checkRect = tester.getRect(find.byType(Icon));
    final label = tester.getRect(find.text(_options[1]));
    expect(checkRect.left - label.right, 6);
  });

  testWidgets('selects by tap, across the 48 target, and by Enter and Space', (
    tester,
  ) async {
    final chosen = <int>[];
    await _pump(tester, _live(onChanged: chosen.add));
    await tester.tap(find.text(_options[2]));
    await tester.pump();
    final strip = tester.getRect(find.byType(ModeChips));
    final first = tester.getRect(_face(_options[0]));
    await tester.tapAt(Offset(first.center.dx, strip.top + 1));
    await tester.pump();
    expect(chosen, [2, 0]);
    expect(_decoration(tester, _options[0]).color, _colors.primarySoft);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(chosen, [2, 0, 1, 2]);
  });

  testWidgets('a labelled radio group; each chip is one radio node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    // Wide enough that no chip is scrolled out of view, and so hidden.
    await _pump(tester, _live(initial: 3), width: 600);
    final group = tester.getSemantics(find.byType(ModeChips));
    expect(group.label, _l10n.searchModesLabel);
    expect(group.role, SemanticsRole.radioGroup);
    for (final (index, option) in _options.indexed) {
      expect(
        tester.getSemantics(find.text(option)),
        matchesSemantics(
          label: option,
          hasCheckedState: true,
          isChecked: index == 3,
          isInMutuallyExclusiveGroup: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
        reason: option,
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, _live());
    expect(_ringDrawn(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester), isTrue);
    expect(
      tester.widget<FocusRing>(find.byType(FocusRing).first).radius,
      BorderRadius.circular(20),
    );

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(_ringDrawn(tester), isFalse);
  });

  testWidgets('scrolls sideways instead of clipping at 200% on 360 wide', (
    tester,
  ) async {
    await _pump(tester, _live(), textScale: 2);
    expect(tester.takeException(), isNull);
    final strip = tester.getRect(find.byType(ModeChips));
    expect(strip.width, 360);
    expect(strip.height, greaterThanOrEqualTo(AppSizes.targetMin));
    // The last chip lies past the left edge until the strip is scrolled.
    expect(tester.getRect(_face(_options.last)).right, lessThan(strip.left));
    await tester.dragUntilVisible(
      find.text(_options.last),
      find.byType(ModeChips),
      const Offset(300, 0),
    );
    expect(
      tester.getRect(_face(_options.last)).left,
      greaterThanOrEqualTo(strip.left),
    );
  });
}
