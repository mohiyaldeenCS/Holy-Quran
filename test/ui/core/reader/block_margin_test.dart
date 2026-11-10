import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/reader_metrics.dart';
import 'package:holyquran/ui/core/metrics/reader_screen_metrics.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/block_margin.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/reader/margin_mark.dart';
import 'package:holyquran/ui/core/reader/margin_row.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/bookmark_ribbon.dart';

import '../../../../testing/golden.dart';
import 'reader_fixture.dart';

const _width = 360.0;
const _height = 640.0;

/// The surah's text as the reader screen lays it out: the column inset by
/// [ReaderMetrics.textInset] on both sides, a row left above each line its
/// margin marks belong to (D-181); with [margin] false, the same layout with
/// no margin layer drawn over it.
Widget _reader(
  SurahText text,
  Map<QuranAddress, BuiltinCategory?> bookmarks, {
  ReadingTheme theme = ReadingTheme.paper,
  Size size = const Size(_width, _height),
  ScrollController? controller,
  bool margin = true,
  Key? surface,
  MarginRowMeasure? rows,
}) => goldenApp(
  theme,
  SizedBox.fromSize(
    size: size,
    child: Builder(
      builder: (context) => CustomScrollView(
        controller: controller,
        slivers: [
          SliverPadding(
            padding: ReaderScreenMetrics.blockPadding,
            sliver: InteractiveSurahSliver(
              text: text,
              marginRows: rows ?? MarginRowMeasure.of(context),
              blockOverlayBuilder: margin
                  ? (context, layout) =>
                        BlockMargin(layout: layout, bookmarks: bookmarks)
                  : null,
            ),
          ),
        ],
      ),
    ),
  ),
  key: surface,
);

/// The labels a screen reader meets, in its order.
List<String> _labels(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) {
      labels.add(
        node.value.isEmpty ? node.label : '${node.label}|${node.value}',
      );
    }
    node
        .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
        .forEach(visit);
  }

  visit(
    tester
        .renderObject(find.byType(CustomScrollView))
        .owner!
        .semanticsOwner!
        .rootSemanticsNode!,
  );
  return labels;
}

void main() {
  late Directory root;
  late ReaderFixture fixture;
  final strings = lookupAppLocalizations(const Locale('ar'));

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('block_margin');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  void setView(WidgetTester tester, [Size size = const Size(_width, _height)]) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a margin mark stands in a row above the line its ayah begins '
      'in, from the start edge of the full text column', (tester) async {
    setView(tester);
    await tester.pumpWidget(_reader(fixture.surahs[longSurah]!, const {}));
    final first = find.byType(MarginMarkView).first;
    final mark = tester.widget<MarginMarkView>(first).mark;
    final block = find.byType(ReaderBlock).first;
    final layout = tester.widget<ReaderBlock>(block).layout;
    expect(layout.plan.width, _width - 2 * ReaderMetrics.textInset);
    final origin = tester.getTopLeft(block);
    expect(origin.dx, ReaderMetrics.textInset);
    // RTL: the start edge is the right one.
    expect(
      tester.getTopRight(first).dx,
      closeTo(_width - ReaderMetrics.textInset, 0.5),
    );
    final line = layout.lineBand(
      layout.plan.lineOfAyahText(mark.ayah) - layout.block.firstLine,
    );
    expect(
      tester.getBottomLeft(first).dy,
      lessThanOrEqualTo(
        origin.dy + line.top - ReaderScreenMetrics.marginRowGap,
      ),
    );
    final (marks, row) = layout.marginRows.first;
    expect(marks.first, mark);
    expect(row.bottom, line.top - ReaderScreenMetrics.marginRowGap);
  });

  testWidgets('a row is as tall as its marks are drawn, at 1.0x and 2.0x, '
      'bold or not', (tester) async {
    for (final (scale, bold) in [
      (1.0, false),
      (2.0, false),
      (1.0, true),
      (2.0, true),
    ]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(boldText: bold);
      final scaler = TextScaler.linear(scale);
      for (final mark in const [
        MarginMark(MarginMarkKind.juz, 1, juz: 28),
        MarginMark(MarginMarkKind.hizb, 1, hizb: 58),
        MarginMark(MarginMarkKind.rub, 1, hizb: 58, quarter: 1),
        MarginMark(MarginMarkKind.rub, 1, hizb: 58, quarter: 3),
        MarginMark(MarginMarkKind.sajda, 1),
      ]) {
        await tester.pumpWidget(
          goldenApp(
            ReadingTheme.paper,
            Align(alignment: Alignment.topRight, child: MarginMarkView(mark)),
          ),
        );
        final name = '${mark.kind.name} ${mark.quarter ?? ''} $scale $bold';
        expect(
          tester.getSize(find.byType(MarginMarkView)).height,
          closeTo(
            MarginMarkView.heightOf(mark, strings, scaler, bold: bold),
            0.5,
          ),
          reason: name,
        );
        expect(
          MarginRowMeasure(
            strings,
            scaler,
            bold: bold,
          ).heightOf([mark, const MarginMark(MarginMarkKind.sajda, 1)]),
          greaterThanOrEqualTo(
            MarginMarkView.heightOf(mark, strings, scaler, bold: bold),
          ),
        );
      }
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  testWidgets('the rows are planned again when their measure changes', (
    tester,
  ) async {
    setView(tester);
    final surah = fixture.surahs[longSurah]!;
    SurahLayout planOf() =>
        tester.widget<ReaderBlock>(find.byType(ReaderBlock).first).layout.plan;
    for (final measure in [
      MarginRowMeasure(strings, TextScaler.noScaling),
      MarginRowMeasure(strings, const TextScaler.linear(2)),
      MarginRowMeasure(strings, const TextScaler.linear(2), bold: true),
    ]) {
      await tester.pumpWidget(_reader(surah, const {}, rows: measure));
      final plan = planOf();
      final line = plan.lineOfAyahText(surah.marginMarks.first.ayah);
      expect(
        plan.rowExtent(line),
        measure.heightOf(plan.marksAbove(line)) +
            ReaderScreenMetrics.marginRowGap,
      );
    }
    final before = planOf();
    await tester.pumpWidget(
      _reader(
        surah,
        const {},
        rows: MarginRowMeasure(strings, const TextScaler.linear(2), bold: true),
      ),
    );
    expect(identical(planOf(), before), isTrue);
  });

  testWidgets('a screen reader meets a margin mark before its ayah, and '
      'cannot focus or activate it', (tester) async {
    final handle = tester.ensureSemantics();
    setView(tester);
    final surah = fixture.surahs[longSurah]!;
    final mark = surah.marginMarks.firstWhere(
      (m) => m.kind == MarginMarkKind.rub && m.quarter == 1,
    );
    await tester.pumpWidget(_reader(surah, const {}));
    final labels = _labels(tester);
    final label =
        '${strings.rubLabel}\n${strings.hizbLabel(arabicDigits(mark.hizb!))}';
    final at = labels.indexOf(label);
    expect(at, isNonNegative);
    expect(
      labels.indexOf(strings.ayahMarkerLabel(arabicDigits(mark.ayah - 1))),
      lessThan(at),
    );
    expect(
      labels.indexOf(surah.ayat[mark.ayah - 1].text.verbatim),
      greaterThan(at),
    );
    expect(
      labels.indexOf(strings.ayahMarkerLabel(arabicDigits(mark.ayah))),
      greaterThan(at),
    );
    final view = find.byWidgetPredicate(
      (w) => w is MarginMarkView && w.mark == mark,
    );
    expect(tester.getSemantics(view).getSemanticsData().actions, 0);
    expect(
      find.descendant(
        of: find.byType(BlockMargin),
        matching: find.byType(Focus),
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('a bookmarked ayah gets its ribbon on the end side, once', (
    tester,
  ) async {
    setView(tester);
    final ayah = fixture.surahs[longSurah]!.addressOf(3);
    await tester.pumpWidget(
      _reader(fixture.surahs[longSurah]!, {ayah: BuiltinCategory.review}),
    );
    final ribbon = find.byType(BookmarkRibbon);
    expect(ribbon, findsOneWidget);
    expect(tester.getTopLeft(ribbon).dx, closeTo(0, 0.5));
    expect(tester.getSize(ribbon), BookmarkRibbon.size);
  });

  testWidgets('the ribbon of an ayah below a row stays level with its line', (
    tester,
  ) async {
    setView(tester);
    final surah = fixture.surahs[longSurah]!;
    final ayah = surah.marginMarks.first.ayah;
    await tester.pumpWidget(_reader(surah, {surah.addressOf(ayah): null}));
    final block = find.byType(ReaderBlock).first;
    final layout = tester.widget<ReaderBlock>(block).layout;
    final line = layout.lineBand(
      layout.plan.lineOfAyahText(ayah) - layout.block.firstLine,
    );
    expect(
      tester.getCenter(find.byType(BookmarkRibbon)).dy,
      closeTo(tester.getTopLeft(block).dy + line.center.dy, 0.5),
    );
  });

  testWidgets('an ayah of another surah gets none', (tester) async {
    setView(tester);
    await tester.pumpWidget(
      _reader(fixture.surahs[longSurah]!, {
        fixture.surahs[1]!.addressOf(1): BuiltinCategory.study,
      }),
    );
    expect(find.byType(BookmarkRibbon), findsNothing);
  });

  testWidgets('a screen reader meets the ribbon after its ayah, with the '
      'category', (tester) async {
    final handle = tester.ensureSemantics();
    setView(tester);
    final ayah = fixture.surahs[longSurah]!.addressOf(3);
    await tester.pumpWidget(
      _reader(fixture.surahs[longSurah]!, {ayah: BuiltinCategory.memorise}),
    );
    final labels = _labels(tester);
    final ribbon = labels.indexOf(
      '${strings.ayahRowBookmark}|${strings.tagMemorise}',
    );
    expect(ribbon, isNonNegative);
    final marker = labels.indexOf(strings.ayahMarkerLabel('٣'));
    final next = labels.indexOf(strings.ayahMarkerLabel('٤'));
    expect(ribbon, greaterThan(marker));
    expect(ribbon, lessThan(next));
    handle.dispose();
  });

  testWidgets('a bookmark with no known category has a bare ribbon, announced '
      'as a bookmark with no category', (tester) async {
    final handle = tester.ensureSemantics();
    setView(tester);
    final ayah = fixture.surahs[longSurah]!.addressOf(3);
    await tester.pumpWidget(_reader(fixture.surahs[longSurah]!, {ayah: null}));
    expect(find.byType(BookmarkRibbon), findsOneWidget);
    final ribbon = tester.widget<BookmarkRibbon>(find.byType(BookmarkRibbon));
    expect(ribbon.shape, isNull);
    expect(ribbon.category, isNull);
    final node = tester.getSemantics(find.byType(BookmarkRibbon));
    expect(node.label, strings.ayahRowBookmark);
    expect(node.value, isEmpty);
    handle.dispose();
  });

  // D-181: a margin mark never touches the text. Each kind of mark, and two
  // marks at one ayah, is set at an ayah whose first line the text fills from
  // edge to edge; the reader is drawn with and without its margin layer at
  // the same scroll offset, and no pixel of text ink may change, nor may a
  // mark's box meet any line's laid box. The column keeps main's width.
  for (final screen in const [Size(412, 915), Size(320, 640)]) {
    for (final theme in ReadingTheme.values) {
      for (final scale in [1.0, 2.0]) {
        final name =
            '${theme.name} at ${scale}x on '
            '${screen.width.toInt()}x${screen.height.toInt()}';
        testWidgets('margin marks touch no text in $name', (tester) async {
          setView(tester, screen);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final base = fixture.surahs[longSurah]!;
          const surface = ValueKey('margin-surface');
          final controller = ScrollController();
          addTearDown(controller.dispose);

          // The lines the reader breaks at this width and scale; rows never
          // change them.
          SurahText withMarks(List<MarginMark> marks) => SurahText(
            riwaya: base.riwaya,
            surah: base.surah,
            ayat: base.ayat,
            basmala: base.basmala,
            pageStarts: base.pageStarts,
            marginMarks: marks,
          );
          await tester.pumpWidget(
            _reader(
              withMarks(const []),
              const {},
              theme: theme,
              size: screen,
              margin: false,
            ),
          );
          final plain = tester
              .widget<ReaderBlock>(find.byType(ReaderBlock).first)
              .layout
              .plan;
          expect(plain.width, screen.width - 2 * ReaderMetrics.textInset);
          final extents = <(double, double)>[];
          for (var b = 0; b < plain.blocks.length; b++) {
            final block = BlockLayout(plain, b, ink: AppColors.paper.quranInk);
            extents.addAll(block.laidLineExtents);
            block.dispose();
          }
          bool full(int line) =>
              extents[line].$1 <= 1 && extents[line].$2 >= plain.width - 1;

          final ayat = <int>[];
          final used = <int>{};
          for (var a = 2; a <= base.ayat.length && ayat.length < 6; a++) {
            final line = plain.lineOfAyahText(a);
            if (!full(line) || used.contains(line)) continue;
            used.add(line);
            ayat.add(a);
          }
          expect(ayat, hasLength(6), reason: 'a full-width line for each');
          final cases = <List<MarginMark>>[
            [MarginMark(MarginMarkKind.juz, ayat[0], juz: 28)],
            [MarginMark(MarginMarkKind.hizb, ayat[1], hizb: 58)],
            [MarginMark(MarginMarkKind.rub, ayat[2], hizb: 58, quarter: 1)],
            [MarginMark(MarginMarkKind.rub, ayat[3], hizb: 58, quarter: 2)],
            [MarginMark(MarginMarkKind.sajda, ayat[4])],
            [
              MarginMark(MarginMarkKind.rub, ayat[5], hizb: 59, quarter: 1),
              MarginMark(MarginMarkKind.sajda, ayat[5]),
            ],
          ];
          final text = withMarks([
            for (final marks in cases)
              ...marks.where((m) => m.kind != MarginMarkKind.sajda),
            for (final marks in cases)
              ...marks.where((m) => m.kind == MarginMarkKind.sajda),
          ]);

          Future<Uint8List> render({required bool margin}) async {
            await tester.pumpWidget(
              _reader(
                text,
                const {},
                theme: theme,
                size: screen,
                controller: controller,
                margin: margin,
                surface: surface,
              ),
            );
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(surface),
            );
            return (await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData();
              image.dispose();
              return bytes!.buffer.asUint8List();
            }))!;
          }

          int pixel(Uint8List bytes, int at) =>
              (0xFF << 24) |
              (bytes[at] << 16) |
              (bytes[at + 1] << 8) |
              bytes[at + 2];

          final ink = AppColors.byId[theme.name]!.quranInk.toARGB32();
          for (final marks in cases) {
            final label = marks.map((m) => m.kind.name).join('+');
            await render(margin: false);
            final plan = tester
                .widget<ReaderBlock>(find.byType(ReaderBlock).first)
                .layout
                .plan;
            expect(plan.width, plain.width);
            final line = plan.lineOfAyahText(marks.first.ayah);
            controller.jumpTo(
              (plan.slotTop(line) - screen.height / 3).clamp(
                0,
                controller.position.maxScrollExtent,
              ),
            );
            final withMarks = await render(margin: true);
            final offset = controller.offset;

            final blocks = [
              for (final element in find.byType(ReaderBlock).evaluate())
                (
                  (element.widget as ReaderBlock).layout,
                  tester.getTopLeft(find.byWidget(element.widget)),
                ),
            ];
            for (final (layout, origin) in blocks) {
              expect(origin.dx, ReaderMetrics.textInset);
              expect(layout.width, screen.width - 2 * ReaderMetrics.textInset);
            }
            final lineBoxes = [
              for (final (layout, origin) in blocks)
                for (final (k, (left, right)) in layout.laidLineExtents.indexed)
                  Rect.fromLTRB(
                    left,
                    layout.lineBand(k).top,
                    right,
                    layout.lineBand(k).bottom,
                  ).shift(origin),
            ];
            final (layout, origin) = blocks.firstWhere(
              (b) => line >= b.$1.block.firstLine && line < b.$1.block.endLine,
            );
            final band = layout
                .lineBand(line - layout.block.firstLine)
                .shift(origin);
            var start = screen.width - ReaderMetrics.textInset;
            for (final mark in marks) {
              final view = find.byWidgetPredicate(
                (w) => w is MarginMarkView && w.mark == mark,
              );
              expect(view, findsOneWidget, reason: label);
              final box = tester.getRect(view);
              for (final lineBox in lineBoxes) {
                expect(
                  box.overlaps(lineBox),
                  isFalse,
                  reason: '$label: its box $box meets a line at $lineBox',
                );
              }
              expect(
                box.bottom,
                lessThanOrEqualTo(
                  band.top - ReaderScreenMetrics.marginRowGap + 0.01,
                ),
                reason: label,
              );
              // In the margin's order from the column's start edge.
              expect(box.right, closeTo(start, 0.5), reason: label);
              start = box.left - ReaderScreenMetrics.marginRowGap;
            }

            final without = await render(margin: false);
            expect(controller.offset, offset);
            var drawn = 0;
            var inkPixels = 0;
            var onInk = 0;
            for (var at = 0; at < without.length; at += 4) {
              final before = pixel(without, at);
              final changed = pixel(withMarks, at) != before;
              if (changed) drawn++;
              if (before != ink) continue;
              inkPixels++;
              if (changed) onInk++;
            }
            expect(onInk, 0, reason: '$label: $onInk mark pixels on text ink');
            expect(drawn, greaterThan(100), reason: '$label was drawn');
            expect(inkPixels, greaterThan(1000), reason: 'the text was drawn');
          }
        });
      }
    }
  }
}
