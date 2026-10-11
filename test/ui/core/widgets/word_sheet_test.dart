import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/word_sheet.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
const _colors = AppColors.paper;
// Synthetic, never Quran text.
final _word = PackText.fromPack(_l10n.sampleWord);
final _row = WordSheetRow(_l10n.sampleRowLabel, _l10n.sampleRowValue);

Future<void> _pump(
  WidgetTester tester,
  Widget sheet, {
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
          child: SingleChildScrollView(child: sheet),
        ),
      ),
    ),
  );
}

WordSheet _sheet({
  Set<WordSheetTab>? tabs,
  WordSheetTab selected = WordSheetTab.irab,
  ValueChanged<WordSheetTab>? onTabSelected,
  List<WordSheetRow>? rows,
  String? note,
}) => WordSheet(
  word: _word,
  wordNumber: 2,
  wordCount: 5,
  tabs: tabs ?? WordSheetTab.values.toSet(),
  selectedTab: selected,
  onTabSelected: onTabSelected ?? (_) {},
  rows: rows ?? [_row, _row],
  note: note,
);

Widget _live({ValueChanged<WordSheetTab>? onSelected}) {
  var selected = WordSheetTab.text;
  return StatefulBuilder(
    builder: (context, setState) => _sheet(
      selected: selected,
      onTabSelected: (tab) {
        onSelected?.call(tab);
        setState(() => selected = tab);
      },
    ),
  );
}

final _tabLabels = [
  _l10n.wordSheetTabText,
  _l10n.wordSheetTabTafsir,
  _l10n.wordSheetTabIrab,
  _l10n.wordSheetTabSarf,
  _l10n.wordSheetTabTajweed,
];

Finder _sheetBox() => find
    .descendant(of: find.byType(WordSheet), matching: find.byType(Container))
    .first;

Finder _handle() => find.descendant(
  of: find.byType(WordSheet),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).color == _colors.lineStrong,
  ),
);

Finder _tabFace(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first;

BoxDecoration _decorationOf(WidgetTester tester, Finder finder) =>
    tester.widget<Container>(finder).decoration! as BoxDecoration;

Finder _rowsBox() => find.descendant(
  of: find.byType(WordSheet),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).color == _colors.surfaceSunk,
  ),
);

String _position() => _l10n.wordSheetPosition('٢', '٥');

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

  testWidgets('a surface sheet, rounded 28 at the top, line on top, shadow', (
    tester,
  ) async {
    await _pump(tester, _sheet());
    final sheet = _decorationOf(tester, _sheetBox());
    expect(sheet.color, _colors.surface);
    expect(sheet.border, Border(top: BorderSide(color: _colors.line)));
    expect(
      sheet.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(AppRadius.radiusSheet)),
    );
    expect(sheet.boxShadow, AppShadows.paper.shadowSheet);
    expect(tester.getSize(find.byType(WordSheet)).width, 360);
  });

  testWidgets('the handle: 44 by 5, line-strong, centred under 1 + 12', (
    tester,
  ) async {
    await _pump(tester, _sheet());
    final sheet = tester.getRect(find.byType(WordSheet));
    final handle = tester.getRect(_handle());
    expect(handle.size, const Size(44, 5));
    expect(handle.top - sheet.top, 1 + AppSpacing.space3);
    expect(handle.center.dx, sheet.center.dx);
    expect(
      _decorationOf(tester, _handle()).borderRadius,
      BorderRadius.circular(3),
    );
  });

  testWidgets('the tabs: 40 high, 16 below the handle, 22 in, 8 apart', (
    tester,
  ) async {
    await _pump(tester, _sheet());
    final sheet = tester.getRect(find.byType(WordSheet));
    final handle = tester.getRect(_handle());
    final first = tester.getRect(_tabFace(_tabLabels[0]));
    final second = tester.getRect(_tabFace(_tabLabels[1]));
    expect(first.height, 40);
    expect(first.top - handle.bottom, AppSpacing.space4);
    // Right to left: the first tab is on the right.
    expect(sheet.right - first.right, 22);
    expect(first.left - second.right, AppSpacing.space2);
    final word = tester.getRect(find.byType(QuranText));
    expect(word.top - first.bottom, AppSpacing.space4);
  });

  testWidgets('the selected tab is primary and bold, the rest outlined', (
    tester,
  ) async {
    await _pump(tester, _sheet());
    for (final (index, label) in _tabLabels.indexed) {
      final on = index == WordSheetTab.irab.index;
      final face = _decorationOf(tester, _tabFace(label));
      final style = tester.widget<Text>(find.text(label)).style!;
      expect(face.borderRadius, BorderRadius.circular(20));
      final border = face.border! as Border;
      expect(border.top.width, 1);
      expect(style.fontSize, 15);
      if (on) {
        expect(face.color, _colors.primary);
        expect(border.top.style, BorderStyle.none);
        expect(style.color, _colors.onPrimary);
        expect(style.fontWeight, FontWeight.w700);
      } else {
        expect(face.color, isNull);
        expect(border, Border.all(color: _colors.line));
        expect(style.color, _colors.inkMuted);
        expect(style.fontWeight, FontWeight.w400);
      }
    }
  });

  testWidgets('shows only the given tabs, in the identity order', (
    tester,
  ) async {
    await _pump(
      tester,
      _sheet(
        tabs: {WordSheetTab.tajweed, WordSheetTab.text, WordSheetTab.irab},
      ),
    );
    expect(find.text(_l10n.wordSheetTabTafsir), findsNothing);
    expect(find.text(_l10n.wordSheetTabSarf), findsNothing);
    final xs = [
      for (final label in [
        _l10n.wordSheetTabText,
        _l10n.wordSheetTabIrab,
        _l10n.wordSheetTabTajweed,
      ])
        tester.getCenter(find.text(label)).dx,
    ];
    expect(xs[0], greaterThan(xs[1]));
    expect(xs[1], greaterThan(xs[2]));
  });

  testWidgets('the word in accent focus Quran text, its place on the left', (
    tester,
  ) async {
    await _pump(tester, _sheet());
    final word = tester.widget<QuranText>(find.byType(QuranText));
    expect(identical(word.text, _word), isTrue);
    expect(word.size, QuranTextSize.focus);
    expect(word.colour, QuranTextColour.accent);
    expect(_position(), 'الكلمة ٢ من ٥');
    final position = tester.widget<Text>(find.text(_position()));
    expect(position.style!.fontSize, 13);
    expect(position.style!.color, _colors.inkMuted);
    final sheet = tester.getRect(find.byType(WordSheet));
    expect(tester.getRect(find.byType(QuranText)).right, sheet.right - 22);
    expect(tester.getRect(find.text(_position())).left, sheet.left + 22);
  });

  testWidgets('rows: a sunk box of label and value, lines between them', (
    tester,
  ) async {
    await _pump(tester, _sheet());
    final box = _decorationOf(tester, _rowsBox());
    expect(box.border, Border.all(color: _colors.line));
    expect(box.borderRadius, BorderRadius.circular(20));
    final boxRect = tester.getRect(_rowsBox());
    final labels = find.text(_l10n.sampleRowLabel);
    final values = find.text(_l10n.sampleRowValue);
    expect(labels, findsNWidgets(2));
    final label = tester.getRect(labels.first);
    final value = tester.getRect(values.first);
    // Border 1, padding 18 at the sides; border 1, padding 4, row padding 12
    // at the top.
    expect(boxRect.right - label.right, 1 + 18);
    expect(value.left - boxRect.left, 1 + 18);
    expect(label.top - boxRect.top, 1 + 4 + AppSpacing.space3);

    final labelStyle = tester.widget<Text>(labels.first).style!;
    expect(labelStyle.fontSize, 16);
    expect(labelStyle.fontWeight, FontWeight.w400);
    expect(labelStyle.color, _colors.inkMuted);
    final valueText = tester.widget<Text>(values.first);
    expect(valueText.style!.fontWeight, FontWeight.w600);
    expect(valueText.style!.color, _colors.ink);
    expect(valueText.textAlign, TextAlign.end);

    final rows = tester.widgetList<Container>(
      find.descendant(of: _rowsBox(), matching: find.byType(Container)),
    );
    expect(rows.map((row) => row.decoration), [
      BoxDecoration(
        border: Border(bottom: BorderSide(color: _colors.line)),
      ),
      null,
    ]);
  });

  testWidgets('the note is 12 ink-muted and centred', (tester) async {
    await _pump(tester, _sheet(note: _l10n.sampleNote));
    final note = tester.widget<Text>(find.text(_l10n.sampleNote));
    expect(note.style!.fontSize, 12);
    expect(note.style!.color, _colors.inkMuted);
    expect(note.textAlign, TextAlign.center);
    final sheet = tester.getRect(find.byType(WordSheet));
    final noteRect = tester.getRect(find.text(_l10n.sampleNote));
    final rows = tester.getRect(_rowsBox());
    expect(noteRect.top - rows.bottom, AppSpacing.space4);
    expect(sheet.bottom - noteRect.bottom, 22);
  });

  testWidgets('hides what has no data: rows, empty values and the note', (
    tester,
  ) async {
    await _pump(tester, _sheet(rows: const []));
    expect(_rowsBox(), findsNothing);
    expect(find.text(_l10n.sampleNote), findsNothing);

    await _pump(
      tester,
      _sheet(rows: [WordSheetRow(_l10n.sampleRowLabel, ''), _row], note: ''),
    );
    expect(find.text(_l10n.sampleRowLabel), findsOneWidget);
    expect(find.text(''), findsNothing);
  });

  testWidgets('selects a tab by tap, across the 48 target, and keyboard', (
    tester,
  ) async {
    final chosen = <WordSheetTab>[];
    await _pump(tester, _live(onSelected: chosen.add));
    await tester.tap(find.text(_l10n.wordSheetTabSarf));
    await tester.pump();
    final face = tester.getRect(_tabFace(_l10n.wordSheetTabTafsir));
    await tester.tapAt(Offset(face.center.dx, face.top - 3));
    await tester.pump();
    expect(chosen, [WordSheetTab.sarf, WordSheetTab.tafsir]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(chosen, [
      WordSheetTab.sarf,
      WordSheetTab.tafsir,
      WordSheetTab.text,
      WordSheetTab.tafsir,
    ]);
  });

  testWidgets('a tab bar of tabs; each tab is one selectable node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      _sheet(tabs: {WordSheetTab.text, WordSheetTab.irab, WordSheetTab.sarf}),
    );
    for (final label in [
      _l10n.wordSheetTabText,
      _l10n.wordSheetTabIrab,
      _l10n.wordSheetTabSarf,
    ]) {
      final node = tester.getSemantics(find.text(label));
      expect(
        node,
        matchesSemantics(
          label: label,
          hasSelectedState: true,
          isSelected: label == _l10n.wordSheetTabIrab,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
        reason: label,
      );
      expect(node.role, SemanticsRole.tab);
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, _sheet());
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

  testWidgets('nothing clips at 200% on 360 wide; the tabs scroll', (
    tester,
  ) async {
    await _pump(tester, _sheet(note: _l10n.sampleNote), textScale: 2);
    expect(tester.takeException(), isNull);
    final sheet = tester.getRect(find.byType(WordSheet));
    final lastTab = tester.getRect(_tabFace(_l10n.wordSheetTabTajweed));
    expect(lastTab.right, lessThan(sheet.left));
    await tester.dragUntilVisible(
      find.text(_l10n.wordSheetTabTajweed),
      find.byType(SingleChildScrollView).last,
      const Offset(300, 0),
    );
    expect(
      tester.getRect(_tabFace(_l10n.wordSheetTabTajweed)).left,
      greaterThanOrEqualTo(sheet.left),
    );
  });
}
