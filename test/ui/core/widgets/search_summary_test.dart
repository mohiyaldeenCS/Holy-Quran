import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/search_summary.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
const _colors = AppColors.paper;
final _title = _l10n.sampleSearchTitle;
final _count = _l10n.sampleSearchCount;
final _sort = _l10n.searchSortMushafOrder;

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

SearchSummary _summary({String? title, VoidCallback? onSort}) => SearchSummary(
  title: title ?? _title,
  count: _count,
  sortLabel: _sort,
  onSort: onSort ?? () {},
);

/// The sort control's drawn face: the box with the line border.
Finder _face() =>
    find.ancestor(of: find.text(_sort), matching: find.byType(Container)).first;

BoxDecoration _faceDecoration(WidgetTester tester) =>
    tester.widget<Container>(_face()).decoration! as BoxDecoration;

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

/// The sort control's 48 target, the outermost box the label sits in.
Finder _target() => find
    .ancestor(of: find.text(_sort), matching: find.byType(GestureDetector))
    .last;

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

  testWidgets('the title 16/700 ink over the count 13 ink-muted', (
    tester,
  ) async {
    await _pump(tester, _summary());
    final title = _style(tester, _title);
    expect(title.fontSize, 16);
    expect(title.fontWeight, FontWeight.w700);
    expect(title.color, _colors.ink);
    expect(title.height, isNull);
    final count = _style(tester, _count);
    expect(count.fontSize, 13);
    expect(count.fontWeight, FontWeight.w400);
    expect(count.color, _colors.inkMuted);
    expect(count.height, isNull);
    final titleRect = tester.getRect(find.text(_title));
    final countRect = tester.getRect(find.text(_count));
    expect(countRect.top, titleRect.bottom);
  });

  testWidgets('right to left: the text at the start, the sort at the end', (
    tester,
  ) async {
    await _pump(tester, _summary());
    final row = tester.getRect(find.byType(SearchSummary));
    expect(row.width, 360 - 2 * AppSpacing.space4);
    expect(tester.getRect(find.text(_title)).right, row.right);
    expect(tester.getRect(find.text(_count)).right, row.right);
    final target = tester.getRect(_target());
    expect(target.left, row.left);
    final face = tester.getRect(_face());
    expect(face.center.dy, row.center.dy);
    expect(
      tester.getRect(find.text(_title)).left - face.right,
      greaterThanOrEqualTo(AppSpacing.space3),
    );
  });

  testWidgets('the sort: a 40 face, line border on surface, radius 14', (
    tester,
  ) async {
    await _pump(tester, _summary());
    expect(tester.getSize(_face()).height, 40);
    final face = _faceDecoration(tester);
    expect(face.color, _colors.surface);
    expect(face.border, Border.all(color: _colors.line));
    expect(face.borderRadius, BorderRadius.circular(14));
    final label = _style(tester, _sort);
    expect(label.fontSize, 14);
    expect(label.fontWeight, FontWeight.w400);
    expect(label.color, _colors.ink);
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.name, IconName.sort);
    expect(icon.size, 18);
    expect(icon.color, _colors.inkMuted);
  });

  testWidgets('the sort: icon then label, 6 apart, padded 12 by 1 border', (
    tester,
  ) async {
    await _pump(tester, _summary());
    final face = tester.getRect(_face());
    final icon = tester.getRect(find.byType(Icon));
    final label = tester.getRect(find.text(_sort));
    expect(face.right - icon.right, 1 + AppSpacing.space3);
    expect(icon.left - label.right, 6);
    expect(label.left - face.left, 1 + AppSpacing.space3);
  });

  testWidgets('calls onSort by tap, across the 48 target, and keyboard', (
    tester,
  ) async {
    var sorts = 0;
    await _pump(tester, _summary(onSort: () => sorts++));
    final target = tester.getRect(_target());
    expect(target.height, AppSizes.targetMin);
    expect(tester.getSize(find.byType(SearchSummary)).height, 48);
    await tester.tap(find.text(_sort));
    await tester.tapAt(Offset(target.center.dx, target.top + 1));
    await tester.tapAt(Offset(target.center.dx, target.bottom - 1));
    expect(sorts, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(sorts, 5);
  });

  testWidgets('reads the title, the count and one labelled sort button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _summary());
    expect(find.bySemanticsLabel(_title), findsOneWidget);
    expect(find.bySemanticsLabel(_count), findsOneWidget);
    expect(
      tester.getSemantics(_target()),
      matchesSemantics(
        label: _sort,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, _summary());
    expect(_ringDrawn(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester), isTrue);
    expect(
      tester.widget<FocusRing>(find.byType(FocusRing)).radius,
      BorderRadius.circular(14),
    );

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(_ringDrawn(tester), isFalse);
  });

  testWidgets('wraps the title instead of clipping at 200% on 360 wide', (
    tester,
  ) async {
    await _pump(
      tester,
      _summary(title: '$_title $_title $_title'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    final row = tester.getRect(find.byType(SearchSummary));
    final title = tester.getRect(find.text('$_title $_title $_title'));
    expect(title.height, greaterThan(2 * 16 * 1.4));
    expect(title.right, row.right);
    expect(tester.getRect(_target()).left, row.left);
    expect(
      tester.getSize(_target()).height,
      greaterThanOrEqualTo(AppSizes.targetMin),
    );
  });
}
