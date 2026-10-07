import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
final _options = [_l10n.tabMushaf, _l10n.tabListen, _l10n.tabStudy];

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
            child: child,
          ),
        ),
      ),
    ),
  );
}

Widget _live({int initial = 0, List<String>? options}) {
  var selected = initial;
  return StatefulBuilder(
    builder: (context, setState) => LevelSwitch(
      options: options ?? _options,
      selectedIndex: selected,
      onChanged: (index) => setState(() => selected = index),
      semanticLabel: _l10n.mainNavigationLabel,
    ),
  );
}

Finder _item(String option) =>
    find.ancestor(of: find.text(option), matching: find.byType(DecoratedBox));

BoxDecoration _decorationOf(WidgetTester tester, Finder finder) =>
    tester.widget<DecoratedBox>(finder.first).decoration as BoxDecoration;

Text _text(WidgetTester tester, String option) =>
    tester.widget<Text>(find.text(option));

void main() {
  testWidgets('a sunk group of equal items, 4 apart, 48 high', (tester) async {
    await _pump(tester, _live());
    final group = tester.getRect(find.byType(LevelSwitch));
    final items = [for (final o in _options) tester.getRect(_item(o).first)];
    expect(group.height, AppSizes.targetMin + 2 * AppSpacing.space1);
    for (final item in items) {
      expect(item.height, AppSizes.targetMin);
      expect(item.width, closeTo(items.first.width, 0.01));
    }
    // Right to left: the first option is on the right.
    expect(group.right - items.first.right, AppSpacing.space1);
    expect(items.first.left - items[1].right, closeTo(AppSpacing.space1, .01));
    final groupDecoration = _decorationOf(
      tester,
      find.descendant(
        of: find.byType(LevelSwitch),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(groupDecoration.color, AppColors.paper.surfaceSunk);
    expect(groupDecoration.borderRadius, BorderRadius.circular(18));
  });

  testWidgets('the selected item is primary and semibold', (tester) async {
    const colors = AppColors.paper;
    await _pump(tester, _live(initial: 1));
    final on = _decorationOf(tester, _item(_options[1]));
    expect(on.color, colors.primary);
    expect(on.borderRadius, BorderRadius.circular(14));
    expect(_text(tester, _options[1]).style!.color, colors.onPrimary);
    expect(_text(tester, _options[1]).style!.fontWeight, FontWeight.w600);

    expect(_decorationOf(tester, _item(_options[0])).color, isNull);
    final off = _text(tester, _options[0]).style!;
    expect(off.color, colors.ink);
    expect(off.fontWeight, FontWeight.w500);
    expect(off.fontSize, 16);
  });

  testWidgets('tapping an item selects it', (tester) async {
    final chosen = <int>[];
    await _pump(
      tester,
      LevelSwitch(
        options: _options,
        selectedIndex: 0,
        onChanged: chosen.add,
        semanticLabel: _l10n.mainNavigationLabel,
      ),
    );
    await tester.tap(find.text(_options[2]));
    await tester.tap(find.text(_options[1]));
    expect(chosen, [2, 1]);
  });

  testWidgets('selects from the keyboard', (tester) async {
    await _pump(tester, _live());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_decorationOf(tester, _item(_options[1])).color, isNotNull);
  });

  testWidgets('each item reads as a button in a one-of group', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _live(initial: 2));
    expect(find.bySemanticsLabel(_l10n.mainNavigationLabel), findsOneWidget);
    for (final (index, option) in _options.indexed) {
      expect(
        tester.getSemantics(find.text(option)),
        matchesSemantics(
          label: option,
          isButton: true,
          hasSelectedState: true,
          isSelected: index == 2,
          isInMutuallyExclusiveGroup: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('wraps and keeps items level at 200% text on 360 wide', (
    tester,
  ) async {
    await _pump(
      tester,
      _live(
        options: [
          _l10n.tabMushaf,
          '${_l10n.mainNavigationLabel} ${_l10n.appTitle}',
          _l10n.tabStudy,
        ],
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    final heights = {
      for (final text in find.byType(Text).evaluate())
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.byWidget(text.widget),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .height,
    };
    expect(heights, hasLength(1));
    expect(heights.single, greaterThan(AppSizes.targetMin));
  });
}
