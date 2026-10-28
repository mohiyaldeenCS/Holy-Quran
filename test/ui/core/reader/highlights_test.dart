import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/highlight_painter.dart';
import 'package:holyquran/ui/core/reader/highlight_shapes.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/reader/reader_highlights.dart';
import 'package:holyquran/ui/core/reader/reader_style.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import '../../../../testing/golden.dart';
import 'reader_fixture.dart';

const _width = 360.0;
const _height = 640.0;

// `.qk-hl-ayah` and `.qk-hl-select`: `padding: 0 4px`.
const _ayahInset = 4.0;

Widget _reader(
  ReaderFixture fixture,
  ReaderHighlights highlights, {
  ReadingTheme theme = ReadingTheme.paper,
  ValueChanged<SurahLayout>? onLayout,
}) => goldenApp(
  theme,
  SizedBox(
    width: _width,
    height: _height,
    child: CustomScrollView(
      slivers: [
        InteractiveSurahSliver(
          text: fixture.surahs[longSurah]!,
          highlights: highlights,
          onLayout: onLayout,
        ),
      ],
    ),
  ),
);

BlockLayout _block(ReaderFixture fixture, [double system = 1]) {
  final plan = SurahLayout.plan(
    fixture.surahs[longSurah]!,
    ReaderStyle(ReaderTextScaler(TextScaler.linear(system), 1)),
    _width,
  );
  return BlockLayout(plan, 0, ink: AppColors.paper.quranInk);
}

Iterable<String> _labels(SemanticsNode node) sync* {
  if (node.label.isNotEmpty) yield node.label;
  for (final child in node.debugListChildrenInOrder(
    DebugSemanticsDumpOrder.traversalOrder,
  )) {
    yield* _labels(child);
  }
}

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('reader_highlights');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  QuranAddress ayah(int number) => fixture.surahs[longSurah]!.addressOf(number);
  QuranAddress word(int number, int word) =>
      QuranAddress(ayah(number).riwaya, ayah(number).surah, number, word);

  group('the shapes of a block', () {
    test('an ayah is one rect for each line, grown by 4 px on each side', () {
      final block = _block(fixture);
      final lines = block.ayahBoxes(5);
      expect(lines, isNotEmpty);
      for (final kind in [
        HighlightKind.recitedAyah,
        HighlightKind.selectedAyah,
      ]) {
        final shapes = highlightShapes(
          block,
          kind == HighlightKind.recitedAyah
              ? ReaderHighlights(recitedAyah: ayah(5))
              : ReaderHighlights(selectedAyah: ayah(5)),
        );
        expect(shapes.map((s) => s.kind).toSet(), {kind});
        expect(shapes, hasLength(lines.length));
        for (final (k, shape) in shapes.indexed) {
          expect(shape.rect.left, lines[k].left - _ayahInset);
          expect(shape.rect.right, lines[k].right + _ayahInset);
          expect(shape.rect.top, greaterThanOrEqualTo(lines[k].top));
          expect(shape.rect.bottom, lessThanOrEqualTo(lines[k].bottom));
          expect(
            shape.rect.center.dy,
            closeTo(lines[k].center.dy, 1e-9),
            reason: 'the font box is in the middle of its line',
          );
        }
      }
      block.dispose();
    });

    test('a word is its box, and a search match for each word', () {
      final block = _block(fixture);
      final box = block.wordBox(5, 2)!;
      final spoken = highlightShapes(
        block,
        ReaderHighlights(spokenWord: word(5, 2)),
      );
      expect(spoken, hasLength(1));
      expect(spoken.single.kind, HighlightKind.spokenWord);
      expect(spoken.single.rect.left, box.left);
      expect(spoken.single.rect.right, box.right);

      final matches = highlightShapes(
        block,
        ReaderHighlights(searchMatches: {word(5, 1), word(6, 1), word(5, 2)}),
      );
      expect(matches.map((s) => s.kind).toSet(), {HighlightKind.searchMatch});
      expect(matches, hasLength(3));
      block.dispose();
    });

    test('only what is in the block, in this surah and riwaya', () {
      final block = _block(fixture);
      final far = ayah(longSurahAyat);
      expect(block.wordBox(longSurahAyat, 1), isNull, reason: 'not in block 0');
      expect(
        highlightShapes(
          block,
          ReaderHighlights(
            selectedAyah: far,
            recitedAyah: far,
            spokenWord: word(longSurahAyat, 1),
            searchMatches: {word(longSurahAyat, 1)},
          ),
        ),
        isEmpty,
      );
      final other = QuranAddress(ayah(5).riwaya, overwideSurah, 1);
      final otherRiwaya = QuranAddress('other', longSurah, 5, 1);
      expect(
        highlightShapes(
          block,
          ReaderHighlights(
            selectedAyah: other,
            recitedAyah: other,
            spokenWord: otherRiwaya,
            searchMatches: {otherRiwaya},
          ),
        ),
        isEmpty,
      );
      expect(highlightShapes(block, ReaderHighlights.none), isEmpty);
      block.dispose();
    });

    test('the same at 200% text', () {
      final block = _block(fixture, 2);
      final shapes = highlightShapes(
        block,
        ReaderHighlights(selectedAyah: ayah(2), spokenWord: word(2, 1)),
      );
      expect(shapes, isNotEmpty);
      for (final shape in shapes) {
        expect(block.lineBands.any((b) => b.overlaps(shape.rect)), isTrue);
        expect(shape.rect.height, lessThanOrEqualTo(block.plan.lineHeight));
      }
      block.dispose();
    });
  });

  group('in the reader', () {
    final all = ReaderHighlights(
      recitedAyah: QuranAddress('hafs', longSurah, 2),
      selectedAyah: QuranAddress('hafs', longSurah, 3),
      spokenWord: QuranAddress('hafs', longSurah, 2, 1),
      searchMatches: {QuranAddress('hafs', longSurah, 4, 1)},
    );

    void setView(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(_width, _height)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('each state has a shape or a line besides its colour, in '
        'every theme', (tester) async {
      setView(tester);
      for (final theme in ReadingTheme.values) {
        await tester.pumpWidget(_reader(fixture, all, theme: theme));
        final colors = buildAppTheme(theme).extension<AppColors>()!;
        final render = tester.renderObject<RenderCustomPaint>(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is HighlightPainter,
          ),
        );
        final shapes = (render.painter! as HighlightPainter).shapes;
        expect(
          shapes.map((s) => s.kind).toSet(),
          HighlightKind.values.toSet(),
          reason: 'all four states are in view',
        );
        // The painter draws the kinds in order, a rect for each line.
        final pattern = paints;
        for (final kind in HighlightKind.values) {
          for (final _ in shapes.where((s) => s.kind == kind)) {
            switch (kind) {
              case HighlightKind.recitedAyah:
                pattern.rrect(color: colors.highlightAyah);
              case HighlightKind.selectedAyah:
                pattern
                  ..rrect(color: colors.selection)
                  ..drrect(color: colors.selectionLine);
              case HighlightKind.searchMatch:
                pattern
                  ..rect(color: colors.searchMatch)
                  ..rect(color: colors.info);
              case HighlightKind.spokenWord:
                pattern
                  ..rect(color: colors.highlightWord)
                  ..rect(color: colors.highlightWordLine);
            }
          }
        }
        expect(render, pattern, reason: theme.name);
      }
    });

    testWidgets('the recited ayah has its marker filled, and only it', (
      tester,
    ) async {
      setView(tester);
      await tester.pumpWidget(_reader(fixture, all));
      final playing = tester
          .widgetList<AyahMarker>(find.byType(AyahMarker))
          .where((m) => m.playing);
      expect(playing.map((m) => m.number), [2]);
      await tester.pumpWidget(_reader(fixture, ReaderHighlights.none));
      expect(
        tester
            .widgetList<AyahMarker>(find.byType(AyahMarker))
            .where((m) => m.playing),
        isEmpty,
      );
    });

    testWidgets('highlights change nothing in the text a reader reads', (
      tester,
    ) async {
      setView(tester);
      final semantics = tester.ensureSemantics();
      List<String> read() => _labels(
        tester
            .renderObject(find.byType(CustomScrollView))
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      ).toList();

      await tester.pumpWidget(_reader(fixture, ReaderHighlights.none));
      final plain = read();
      await tester.pumpWidget(_reader(fixture, all));
      final highlighted = read();
      expect(highlighted, plain);
      final stored = [
        for (final (_, bytes) in fixture.pack.raw.ayat(longSurah).take(6))
          utf8.decode(bytes),
      ];
      for (final text in stored) {
        expect(highlighted, contains(text));
      }
      final layout = tester
          .widget<ReaderBlock>(find.byType(ReaderBlock).first)
          .layout;
      expect(layout.plan.text, same(fixture.surahs[longSurah]));
      semantics.dispose();
    });

    testWidgets('a new highlight repaints without planning the text again', (
      tester,
    ) async {
      setView(tester);
      final plans = <SurahLayout>[];
      await tester.pumpWidget(
        _reader(fixture, ReaderHighlights.none, onLayout: plans.add),
      );
      await tester.pump();
      await tester.pumpWidget(_reader(fixture, all, onLayout: plans.add));
      await tester.pump();
      await tester.pumpWidget(
        _reader(
          fixture,
          ReaderHighlights(spokenWord: QuranAddress('hafs', longSurah, 2, 2)),
          onLayout: plans.add,
        ),
      );
      await tester.pump();
      expect(plans, hasLength(1));
    });
  });

  test('highlights compare by value', () {
    ReaderHighlights make() => ReaderHighlights(
      selectedAyah: QuranAddress('hafs', 2, 3),
      searchMatches: {QuranAddress('hafs', 2, 3, 1)},
    );
    expect(make(), make());
    expect(make().hashCode, make().hashCode);
    expect(make(), isNot(ReaderHighlights.none));
    expect(ReaderHighlights.none.isEmpty, isTrue);
  });
}
