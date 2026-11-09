import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/reader_metrics.dart';
import 'package:holyquran/ui/core/metrics/reader_screen_metrics.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/block_margin.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/reader/margin_gutter.dart';
import 'package:holyquran/ui/core/reader/margin_mark.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/bookmark_ribbon.dart';

import '../../../../testing/golden.dart';
import 'reader_fixture.dart';

const _width = 360.0;
const _height = 640.0;

/// The surah's text as the reader screen lays it out: the start gutter the
/// margin marks take, the end side the column's inset (D-181); with
/// [margin] false, the same text with no margin layer.
Widget _reader(
  SurahText text,
  Map<QuranAddress, BuiltinCategory?> bookmarks, {
  ReadingTheme theme = ReadingTheme.paper,
  Size size = const Size(_width, _height),
  ScrollController? controller,
  bool margin = true,
  Key? surface,
}) => goldenApp(
  theme,
  SizedBox.fromSize(
    size: size,
    child: MarginGutter(
      builder: (context, gutter) => CustomScrollView(
        controller: controller,
        slivers: [
          SliverPadding(
            padding: ReaderScreenMetrics.textPadding(gutter),
            sliver: InteractiveSurahSliver(
              text: text,
              blockOverlayBuilder: margin
                  ? (context, layout) => BlockMargin(
                      layout: layout,
                      startGutter: gutter,
                      bookmarks: bookmarks,
                    )
                  : null,
            ),
          ),
        ],
      ),
    ),
  ),
  key: surface,
);

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('block_margin');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  void setView(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(_width, _height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('margin marks stand in the start gutter, from the screen\'s '
      'edge, level with their line', (tester) async {
    setView(tester);
    await tester.pumpWidget(_reader(fixture.surahs[longSurah]!, const {}));
    final views = tester.widgetList<MarginMarkView>(
      find.byType(MarginMarkView),
    );
    expect(views, isNotEmpty);
    final first = find.byType(MarginMarkView).first;
    final block = find.byType(ReaderBlock).first;
    final layout = tester.widget<ReaderBlock>(block).layout;
    // RTL: the start edge is the right one. The mark begins at the screen's
    // edge and ends the gap short of the text.
    final columnStart = tester.getTopRight(block).dx;
    final gutter = _width - columnStart;
    expect(layout.plan.width, _width - gutter - ReaderMetrics.textInset);
    expect(tester.getTopRight(first).dx, closeTo(_width, 0.5));
    expect(
      tester.getTopLeft(first).dx,
      greaterThanOrEqualTo(columnStart + ReaderScreenMetrics.marginGutterGap),
    );
    final (mark, band) = layout.marginMarks.first;
    expect(views.first.mark, mark);
    expect(
      tester.getCenter(first).dy,
      closeTo(tester.getTopLeft(block).dy + band.center.dy, 0.5),
    );
  });

  testWidgets('the gutter is the widest mark at the text scale, and the gap', (
    tester,
  ) async {
    final strings = lookupAppLocalizations(const Locale('ar'));
    for (final (scale, bold) in [
      (1.0, false),
      (2.0, false),
      (1.0, true),
      (2.0, true),
    ]) {
      final scaler = TextScaler.linear(scale);
      final widest = MarginMarkView.widest(strings, scaler, bold: bold);
      expect(
        ReaderScreenMetrics.startGutter(widest),
        widest.ceilToDouble() + ReaderScreenMetrics.marginGutterGap,
      );
      if (bold) {
        expect(widest, greaterThan(MarginMarkView.widest(strings, scaler)));
      }
      // Each kind as drawn is no wider than measured.
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(boldText: bold);
      for (final mark in const [
        MarginMark(MarginMarkKind.juz, 1, juz: 28),
        MarginMark(MarginMarkKind.hizb, 1, hizb: 58),
        MarginMark(MarginMarkKind.rub, 1, hizb: 58, quarter: 1),
        MarginMark(MarginMarkKind.rub, 1, hizb: 58, quarter: 3),
        MarginMark(MarginMarkKind.sajda, 1),
      ]) {
        await tester.pumpWidget(
          goldenApp(ReadingTheme.paper, MarginMarkView(mark)),
        );
        final drawn = tester.getSize(find.byType(MarginMarkView)).width;
        expect(
          drawn,
          lessThanOrEqualTo(widest + 0.01),
          reason: '${mark.kind} ${mark.quarter}',
        );
        expect(
          drawn,
          closeTo(
            MarginMarkView.widthOf(mark, strings, scaler, bold: bold),
            0.5,
          ),
          reason: '${mark.kind} ${mark.quarter}',
        );
      }
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  testWidgets('with bold text the gutter widens and the mark stays in it', (
    tester,
  ) async {
    setView(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(boldText: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_reader(fixture.surahs[longSurah]!, const {}));
    final strings = lookupAppLocalizations(const Locale('ar'));
    final gutter = ReaderScreenMetrics.startGutter(
      MarginMarkView.widest(strings, TextScaler.noScaling, bold: true),
    );
    final block = find.byType(ReaderBlock).first;
    expect(tester.getTopRight(block).dx, _width - gutter);
    for (final mark in find.byType(MarginMarkView).evaluate()) {
      expect(
        tester.getTopLeft(find.byWidget(mark.widget)).dx,
        greaterThanOrEqualTo(
          _width - gutter + ReaderScreenMetrics.marginGutterGap,
        ),
      );
    }
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
    final l10n = lookupAppLocalizations(const Locale('ar'));
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
    final ribbon = labels.indexOf(
      '${l10n.ayahRowBookmark}|${l10n.tagMemorise}',
    );
    expect(ribbon, isNonNegative);
    final marker = labels.indexOf(l10n.ayahMarkerLabel('٣'));
    final next = labels.indexOf(l10n.ayahMarkerLabel('٤'));
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
    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(find.byType(BookmarkRibbon), findsOneWidget);
    final ribbon = tester.widget<BookmarkRibbon>(find.byType(BookmarkRibbon));
    expect(ribbon.shape, isNull);
    expect(ribbon.category, isNull);
    final node = tester.getSemantics(find.byType(BookmarkRibbon));
    expect(node.label, l10n.ayahRowBookmark);
    expect(node.value, isEmpty);
    handle.dispose();
  });

  // D-181: a margin mark never touches the text. Each mark is set beside a
  // line the text fills from edge to edge, the reader is drawn with and
  // without its margin layer at the same scroll offset, and no pixel of
  // text ink may change; nor may a mark's box meet its line's laid extent.
  const screen = Size(412, 915);
  for (final theme in ReadingTheme.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('margin marks touch no text in ${theme.name} at ${scale}x', (
        tester,
      ) async {
        tester.view
          ..physicalSize = screen
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final strings = lookupAppLocalizations(const Locale('ar'));
        final scaler = TextScaler.linear(scale);
        final base = fixture.surahs[longSurah]!;
        const surface = ValueKey('margin-surface');
        final controller = ScrollController();
        addTearDown(controller.dispose);

        // The plan the reader makes at this width and scale.
        await tester.pumpWidget(
          _reader(base, const {}, theme: theme, size: screen, margin: false),
        );
        final plan = tester
            .widget<ReaderBlock>(find.byType(ReaderBlock).first)
            .layout
            .plan;
        final extents = <(double, double)>[];
        for (var b = 0; b < plan.blocks.length; b++) {
          final block = BlockLayout(plan, b, ink: AppColors.paper.quranInk);
          extents.addAll(block.laidLineExtents);
          block.dispose();
        }
        bool full(int line) =>
            extents[line].$1 <= 1 && extents[line].$2 >= plan.width - 1;

        int widestOf(int count, MarginMark Function(int) mark) {
          var best = 1;
          for (var n = 2; n <= count; n++) {
            if (MarginMarkView.widthOf(mark(n), strings, scaler) >
                MarginMarkView.widthOf(mark(best), strings, scaler)) {
              best = n;
            }
          }
          return best;
        }

        final juz = widestOf(
          30,
          (n) => MarginMark(MarginMarkKind.juz, 1, juz: n),
        );
        final hizb = widestOf(
          60,
          (n) => MarginMark(MarginMarkKind.rub, 1, hizb: n, quarter: 1),
        );
        final kinds = <MarginMark Function(int)>[
          (a) => MarginMark(MarginMarkKind.juz, a, juz: juz),
          (a) => MarginMark(MarginMarkKind.hizb, a, hizb: hizb),
          (a) => MarginMark(MarginMarkKind.rub, a, hizb: hizb, quarter: 1),
          (a) => MarginMark(MarginMarkKind.rub, a, hizb: hizb, quarter: 2),
          (a) => MarginMark(MarginMarkKind.sajda, a),
        ];
        final marks = <MarginMark>[];
        final used = <int>{};
        for (var a = 1; a <= base.ayat.length && marks.length < 5; a++) {
          final make = kinds[marks.length];
          final sajda = marks.length == 4;
          final line = sajda ? plan.lineOfAyahEnd(a) : plan.lineOfAyahText(a);
          if (!full(line) || used.contains(line)) continue;
          used.add(line);
          marks.add(make(a));
        }
        expect(marks, hasLength(5), reason: 'a full-width line for each');
        final text = SurahText(
          riwaya: base.riwaya,
          surah: base.surah,
          ayat: base.ayat,
          basmala: base.basmala,
          pageStarts: base.pageStarts,
          marginMarks: marks,
        );

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
        for (final mark in marks) {
          final sajda = mark.kind == MarginMarkKind.sajda;
          final line = sajda
              ? plan.lineOfAyahEnd(mark.ayah)
              : plan.lineOfAyahText(mark.ayah);
          await render(margin: false);
          controller.jumpTo(
            (plan.basmalaExtent + line * plan.lineHeight - screen.height / 3)
                .clamp(0, controller.position.maxScrollExtent),
          );
          final offset = controller.offset;
          final withMarks = await render(margin: true);
          expect(controller.offset, offset);
          final name = '${mark.kind.name} ${mark.quarter ?? ''}';

          final view = find.byWidgetPredicate(
            (w) => w is MarginMarkView && w.mark == mark,
          );
          expect(view, findsOneWidget, reason: name);
          final box = tester.getRect(view);
          final block = find.byType(ReaderBlock).evaluate().firstWhere((e) {
            final layout = (e.widget as ReaderBlock).layout;
            return line >= layout.block.firstLine &&
                line < layout.block.endLine;
          });
          final layout = (block.widget as ReaderBlock).layout;
          final origin = tester.getTopLeft(find.byWidget(block.widget));
          final (left, right) = extents[line];
          final band = layout.lineBand(line - layout.block.firstLine);
          final laid = Rect.fromLTRB(
            left,
            band.top,
            right,
            band.bottom,
          ).shift(origin);
          expect(
            box.overlaps(laid),
            isFalse,
            reason: '$name: its box $box meets its line $laid',
          );
          expect(box.right, closeTo(screen.width, 0.5), reason: name);
          expect(
            box.left,
            greaterThanOrEqualTo(
              origin.dx + plan.width + ReaderScreenMetrics.marginGutterGap,
            ),
            reason: name,
          );

          final without = await render(margin: false);
          expect(controller.offset, offset);
          var label = 0;
          var inkPixels = 0;
          var onInk = 0;
          for (var at = 0; at < without.length; at += 4) {
            final before = pixel(without, at);
            final changed = pixel(withMarks, at) != before;
            if (changed) label++;
            if (before != ink) continue;
            inkPixels++;
            if (changed) onInk++;
          }
          expect(onInk, 0, reason: '$name: $onInk label pixels on text ink');
          expect(label, greaterThan(100), reason: '$name was drawn');
          expect(inkPixels, greaterThan(1000), reason: 'the text was drawn');
        }
      });
    }
  }
}
