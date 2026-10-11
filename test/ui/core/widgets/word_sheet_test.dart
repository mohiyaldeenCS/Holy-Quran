import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

// Synthetic words of 9, 12 and 14 letters, long enough at the focus size to
// crowd out the word's place or the sheet itself.
const _longWords = ['تجريبيتان', 'فالتجريبيتان', 'تجريبيةتجريبية'];

Future<void> _pump(
  WidgetTester tester,
  Widget sheet, {
  double textScale = 1,
  double width = 360,
  bool disableAnimations = false,
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
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: SingleChildScrollView(child: sheet),
        ),
      ),
    ),
  );
}

WordSheet _sheet({
  PackText? word,
  Set<WordSheetTab>? tabs,
  WordSheetTab selected = WordSheetTab.irab,
  ValueChanged<WordSheetTab>? onTabSelected,
  List<WordSheetRow>? rows,
  String? note,
}) {
  final shown = rows ?? [_row, _row];
  return WordSheet(
    word: word ?? _word,
    wordNumber: 2,
    wordCount: 5,
    tabs: tabs ?? WordSheetTab.values.toSet(),
    selectedTab: selected,
    onTabSelected: onTabSelected ?? (_) {},
    rows: shown,
    // Rows come with their source (WordSheet README).
    note: note ?? (shown.isEmpty ? null : _l10n.sampleNote),
  );
}

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

/// Whether the focus ring of the tab labelled [label] is drawn.
bool _ringOn(WidgetTester tester, String label) =>
    tester
        .widget<CustomPaint>(
          find
              .descendant(
                of: find.ancestor(
                  of: find.text(label),
                  matching: find.byType(FocusRing),
                ),
                matching: find.byType(CustomPaint),
              )
              .first,
        )
        .foregroundPainter !=
    null;

Finder _strip() => find.descendant(
  of: find.byType(WordSheet),
  matching: find.byType(SingleChildScrollView),
);

Finder _wordText() => find.descendant(
  of: find.byType(QuranText),
  matching: find.byType(RichText),
);

/// The lines [paragraph] is laid out in.
int _lines(RenderParagraph paragraph) => paragraph
    .getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: paragraph.text.toPlainText().length,
      ),
      boxHeightStyle: BoxHeightStyle.max,
    )
    .map((box) => box.top)
    .toSet()
    .length;

/// The width [paragraph] takes on one line.
double _naturalWidth(RenderParagraph paragraph) =>
    paragraph.getMaxIntrinsicWidth(double.infinity);

/// Where the alphabetic baseline of [text] lies on screen.
double _baseline(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  return tester.getRect(text).top +
      paragraph.getDryBaseline(paragraph.constraints, TextBaseline.alphabetic)!;
}

Future<void> _shiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
}

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

    await _pump(tester, _sheet(rows: const [], note: ''));
    expect(_rowsBox(), findsNothing);
    expect(find.text(''), findsNothing);

    await _pump(
      tester,
      _sheet(rows: [WordSheetRow(_l10n.sampleRowLabel, ''), _row]),
    );
    expect(find.text(_l10n.sampleRowLabel), findsOneWidget);
    expect(find.text(''), findsNothing);
  });

  test('rows need the note that names their source', () {
    WordSheet sheet({List<WordSheetRow> rows = const [], String? note}) =>
        WordSheet(
          word: _word,
          wordNumber: 1,
          wordCount: 1,
          tabs: {WordSheetTab.text},
          selectedTab: WordSheetTab.text,
          onTabSelected: (_) {},
          rows: rows,
          note: note,
        );

    expect(() => sheet(rows: [_row]), throwsAssertionError);
    expect(() => sheet(rows: [_row], note: ''), throwsAssertionError);
    expect(sheet(rows: [_row], note: _l10n.sampleNote), isA<WordSheet>());
    expect(sheet(), isA<WordSheet>());
  });

  testWidgets('the selected tab must be one of the tabs shown', (tester) async {
    await _pump(
      tester,
      _sheet(
        tabs: {WordSheetTab.text, WordSheetTab.sarf},
        selected: WordSheetTab.sarf,
      ),
    );
    expect(tester.takeException(), isNull);
    await _pump(tester, _sheet(tabs: {WordSheetTab.text, WordSheetTab.sarf}));
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('a row: the label at its own width, the value in the rest', (
    tester,
  ) async {
    // About 204 px at 16/600: more than half the row, less than the label
    // leaves, on a 390 sheet.
    const value = 'قيمة تجريبية طويلة في سطر واحد';
    await _pump(
      tester,
      _sheet(rows: [WordSheetRow(_l10n.sampleRowLabel, value)]),
      width: 390,
    );
    final box = tester.getRect(_rowsBox());
    final label = find.text(_l10n.sampleRowLabel);
    final valueText = find.text(value);
    final labelRect = tester.getRect(label);
    final valueRect = tester.getRect(valueText);
    final valueParagraph = tester.renderObject<RenderParagraph>(valueText);
    // Border 1 and padding 18 on each side; gap 16 between the two.
    final inner = box.width - 2 * (1 + 18);
    expect(_naturalWidth(valueParagraph), greaterThan((inner - 16) / 2));
    expect(
      labelRect.width,
      closeTo(_naturalWidth(tester.renderObject<RenderParagraph>(label)), 0.01),
    );
    expect(_lines(valueParagraph), 1);
    expect(labelRect.right, box.right - 1 - 18);
    expect(valueRect.left, box.left + 1 + 18);
    expect(valueRect.right, labelRect.left - AppSpacing.space4);
  });

  testWidgets('a long value wraps inside the value column only', (
    tester,
  ) async {
    const value =
        'قيمة تجريبية طويلة جدًا تلتف على أكثر من سطر واحد في عمود القيمة '
        'وحده دون أن تمس العنوان';
    await _pump(
      tester,
      _sheet(rows: [WordSheetRow(_l10n.sampleRowLabel, value)]),
      width: 390,
    );
    final box = tester.getRect(_rowsBox());
    final label = find.text(_l10n.sampleRowLabel);
    final valueText = find.text(value);
    final labelRect = tester.getRect(label);
    final valueRect = tester.getRect(valueText);
    expect(
      _lines(tester.renderObject<RenderParagraph>(valueText)),
      greaterThan(1),
    );
    expect(_lines(tester.renderObject<RenderParagraph>(label)), 1);
    expect(
      labelRect.width,
      closeTo(_naturalWidth(tester.renderObject<RenderParagraph>(label)), 0.01),
    );
    expect(labelRect.right, box.right - 1 - 18);
    expect(valueRect.left, box.left + 1 + 18);
    expect(valueRect.right, labelRect.left - AppSpacing.space4);
    // .qk-sheet-row stretches its items, so both start at the row's top.
    expect(labelRect.top, valueRect.top);
    expect(tester.widget<Text>(valueText).textAlign, TextAlign.end);
  });

  testWidgets('the word is drawn whole on one line: its place moves under '
      'it, and a word wider than the sheet is scaled down', (tester) async {
    var beside = 0;
    var under = 0;
    var scaled = 0;
    for (final width in [360.0, 390.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final value in _longWords) {
          final where = '$value at $scale on $width';
          await _pump(
            tester,
            _sheet(word: PackText.fromPack(value)),
            width: width,
            textScale: scale,
          );
          expect(tester.takeException(), isNull, reason: where);
          final sheet = tester.getRect(find.byType(WordSheet));
          final left = sheet.left + 22;
          final right = sheet.right - 22;
          final paragraph = tester.renderObject<RenderParagraph>(_wordText());
          final word = tester.getRect(_wordText());
          final position = find.text(_position());
          final place = tester.getRect(position);
          final natural = _naturalWidth(paragraph);

          expect(_lines(paragraph), 1, reason: where);
          expect(word.right, closeTo(right, 0.01), reason: where);
          expect(word.left, greaterThanOrEqualTo(left - 0.01), reason: where);
          if (natural > right - left) {
            scaled++;
            expect(word.width, closeTo(right - left, 0.01), reason: where);
          }
          final placeWidth = _naturalWidth(
            tester.renderObject<RenderParagraph>(position),
          );
          if (natural + placeWidth <= right - left) {
            beside++;
            expect(place.left, closeTo(left, 0.01), reason: where);
            expect(place.right, lessThanOrEqualTo(word.left), reason: where);
            expect(
              _baseline(tester, position),
              closeTo(_baseline(tester, _wordText()), 0.01),
              reason: where,
            );
          } else {
            under++;
            expect(place.right, closeTo(right, 0.01), reason: where);
            expect(place.top, closeTo(word.bottom, 0.01), reason: where);
            expect(place.left, greaterThanOrEqualTo(left), reason: where);
          }
        }
      }
    }
    expect(beside, greaterThan(0));
    expect(under, greaterThan(0));
    expect(scaled, greaterThan(0));
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

  for (final scale in [1.0, 2.0]) {
    testWidgets('keyboard focus scrolls each tab into view, at '
        '${(scale * 100).round()}% on 360 wide', (tester) async {
      await _pump(tester, _sheet(), textScale: scale);
      final strip = tester.getRect(_strip());
      expect(
        tester.getRect(_tabFace(_tabLabels.last)).left,
        lessThan(strip.left),
      );

      for (final label in _tabLabels) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(_ringOn(tester, label), isTrue, reason: label);
        final face = tester.getRect(_tabFace(label));
        expect(face.left, greaterThanOrEqualTo(strip.left), reason: label);
        expect(face.right, lessThanOrEqualTo(strip.right), reason: label);
      }
      for (final label in _tabLabels.reversed.skip(1)) {
        await _shiftTab(tester);
        await tester.pumpAndSettle();
        expect(_ringOn(tester, label), isTrue, reason: label);
        final face = tester.getRect(_tabFace(label));
        expect(face.left, greaterThanOrEqualTo(strip.left), reason: label);
        expect(face.right, lessThanOrEqualTo(strip.right), reason: label);
      }
    });
  }

  testWidgets('with reduced motion the strip jumps to the focused tab', (
    tester,
  ) async {
    await _pump(tester, _sheet(), disableAnimations: true);
    final strip = tester.getRect(_strip());
    for (var i = 0; i < _tabLabels.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pump();
    final face = tester.getRect(_tabFace(_tabLabels.last));
    expect(face.left, greaterThanOrEqualTo(strip.left));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
