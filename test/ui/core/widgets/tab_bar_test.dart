import 'package:flutter/material.dart' hide Icon, TabBar;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/tab_bar.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

final _items = [
  TabBarItem(IconName.home, _l10n.tabHome),
  TabBarItem(IconName.mushaf, _l10n.tabMushaf),
  TabBarItem(IconName.listen, _l10n.tabListen),
  TabBarItem(IconName.study, _l10n.tabStudy),
  TabBarItem(IconName.more, _l10n.tabMore),
];

Future<void> _pump(
  WidgetTester tester,
  Widget bar, {
  double textScale = 1,
  double safeBottom = 0,
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
            viewPadding: EdgeInsets.only(bottom: safeBottom),
            padding: EdgeInsets.only(bottom: safeBottom),
          ),
          child: Align(alignment: Alignment.bottomCenter, child: bar),
        ),
      ),
    ),
  );
}

Widget _live({int initial = 0}) {
  var current = initial;
  return StatefulBuilder(
    builder: (context, setState) => TabBar(
      items: _items,
      currentIndex: current,
      onSelected: (index) => setState(() => current = index),
      semanticLabel: _l10n.mainNavigationLabel,
    ),
  );
}

Finder _tab(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(ConstrainedBox))
    .first;

Finder _pill(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is Icon && widget.name == _iconOf(label),
  ),
  matching: find.byType(Container),
);

IconName _iconOf(String label) =>
    _items.firstWhere((item) => item.label == label).icon;

BoxDecoration _pillDecoration(WidgetTester tester, String label) =>
    tester.widget<Container>(_pill(label).first).decoration! as BoxDecoration;

TextStyle _labelStyle(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!;

void main() {
  testWidgets('a surface bar under a line hairline, padded 8 8 8 20', (
    tester,
  ) async {
    await _pump(tester, _live());
    final bar = tester.getRect(find.byType(TabBar));
    final container = tester.widget<Container>(
      find
          .descendant(of: find.byType(TabBar), matching: find.byType(Container))
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.paper.surface);
    expect(
      decoration.border,
      Border(top: BorderSide(color: AppColors.paper.line)),
    );

    final tabs = [for (final item in _items) tester.getRect(_tab(item.label))];
    expect(bar.width, 360);
    expect(tabs.first.top - bar.top, 1 + AppSpacing.space2);
    expect(bar.bottom - tabs.first.bottom, 20);
    expect(bar.right - tabs.first.right, AppSpacing.space2);
    expect(tabs.last.left - bar.left, AppSpacing.space2);
    for (final tab in tabs) {
      expect(tab.width, closeTo((360 - 2 * AppSpacing.space2) / 5, .01));
      expect(tab.height, tabs.first.height);
      expect(tab.height, greaterThanOrEqualTo(AppSizes.targetMin));
    }
  });

  testWidgets('the first tab is on the right, in order to the left', (
    tester,
  ) async {
    await _pump(tester, _live());
    final xs = [for (final item in _items) tester.getCenter(_tab(item.label))];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i].dx, lessThan(xs[i - 1].dx), reason: _items[i].label);
    }
  });

  testWidgets('the current tab has a soft pill and a semibold label', (
    tester,
  ) async {
    const colors = AppColors.paper;
    await _pump(tester, _live(initial: 3));
    for (final (index, item) in _items.indexed) {
      final on = index == 3;
      final pill = tester.getSize(_pill(item.label).first);
      expect(pill, const Size(60, 32));
      final decoration = _pillDecoration(tester, item.label);
      expect(decoration.color, on ? colors.primarySoft : isNull);
      expect(decoration.borderRadius, BorderRadius.circular(16));

      final foreground = on ? colors.onPrimarySoft : colors.inkMuted;
      final icon = tester.widget<Icon>(
        find.descendant(
          of: _pill(item.label).first,
          matching: find.byType(Icon),
        ),
      );
      expect(icon.color, foreground);
      expect(icon.size, AppSizes.iconSize);

      final style = _labelStyle(tester, item.label);
      expect(style.color, foreground);
      expect(style.fontWeight, on ? FontWeight.w600 : FontWeight.w500);
      expect(style.fontSize, AppTextStyles.tabLabel.fontSize);
      expect(style.height, AppTextStyles.tabLabel.height);
      expect(style.fontFamily, AppTextStyles.tabLabel.fontFamily);
    }
    final pill = tester.getRect(_pill(_items[3].label).first);
    final tab = tester.getRect(_tab(_items[3].label));
    final label = tester.getRect(find.text(_items[3].label));
    expect(pill.top - tab.top, 6);
    expect(label.top - pill.bottom, 2);
    expect(pill.center.dx, closeTo(tab.center.dx, .01));
  });

  testWidgets('the bottom padding grows to the safe area', (tester) async {
    await _pump(tester, _live(), safeBottom: 34);
    final bar = tester.getRect(find.byType(TabBar));
    final tab = tester.getRect(_tab(_items.first.label));
    expect(bar.bottom - tab.bottom, 34);

    await _pump(tester, _live(), safeBottom: 12);
    final smallBar = tester.getRect(find.byType(TabBar));
    final smallTab = tester.getRect(_tab(_items.first.label));
    expect(smallBar.bottom - smallTab.bottom, 20);
  });

  testWidgets('tapping a tab reports its index', (tester) async {
    final chosen = <int>[];
    await _pump(
      tester,
      TabBar(
        items: _items,
        currentIndex: 0,
        onSelected: chosen.add,
        semanticLabel: _l10n.mainNavigationLabel,
      ),
    );
    await tester.tap(find.text(_l10n.tabStudy));
    await tester.tap(_pill(_l10n.tabMushaf).first);
    await tester.tap(find.text(_l10n.tabHome));
    expect(chosen, [3, 1, 0]);
  });

  testWidgets('selects from the keyboard', (tester) async {
    await _pump(tester, _live());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_pillDecoration(tester, _l10n.tabMushaf).color, isNotNull);
    expect(_pillDecoration(tester, _l10n.tabHome).color, isNull);
  });

  testWidgets('a named group of buttons, the current one selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _live(initial: 2));
    expect(find.bySemanticsLabel(_l10n.mainNavigationLabel), findsOneWidget);
    for (final (index, item) in _items.indexed) {
      expect(
        tester.getSemantics(find.text(item.label)),
        matchesSemantics(
          label: item.label,
          isButton: true,
          hasSelectedState: true,
          isSelected: index == 2,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('every label stays on one line up to 150% on 360 wide', (
    tester,
  ) async {
    // The widest label, the current tab's «المصحف», is 44.4 wide at 100% and
    // a tab is 68.8 wide at 360: it fits up to a scale of 1.55.
    for (final current in [0, 1, 2, 3, 4]) {
      await _pump(tester, _live(initial: current), textScale: 1.5);
      expect(tester.takeException(), isNull);
      for (final item in _items) {
        final height = tester.getSize(find.text(item.label)).height;
        expect(height, closeTo(12 * 1.5 * 1.4, 1), reason: item.label);
      }
    }
  });

  testWidgets('lays out without overflow at 200% on 360 wide', (tester) async {
    for (final current in [0, 3]) {
      await _pump(tester, _live(initial: current), textScale: 2);
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(find.byType(TabBar));
      expect(bar.width, 360);
      final tabs = [
        for (final item in _items) tester.getRect(_tab(item.label)),
      ];
      for (final (index, item) in _items.indexed) {
        final label = tester.getRect(find.text(item.label));
        expect(tabs[index].contains(label.topLeft), isTrue, reason: item.label);
        expect(
          tabs[index].contains(label.bottomRight - const Offset(.01, .01)),
          isTrue,
          reason: item.label,
        );
        expect(tabs[index].height, tabs.first.height);
      }
    }
  });
}
