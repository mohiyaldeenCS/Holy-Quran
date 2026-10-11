import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import '../../s7/gesture_target.dart';
import '../../s7/reader_gestures.dart';
import '../../s7/tap_resolver.dart';
import 'highlight_painter.dart';
import 'page_blocks_v2.dart';
import 'render_checks.dart';
import 'spike_surah_text.dart';
import 'surah_list_v1.dart';
import 'surah_paragraph.dart';
import 'surah_text_block.dart';
import 'synthetic_surah_pack.dart';

// Every text is Arabic-script nonsense from the spike writer's pack with
// marks (D-083), read through the app's verification and text repository.

const _pageMark = Size(30, 20);
const _height = 800.0;

Widget _pageMarkOf(BuildContext context, int page) =>
    SizedBox(key: ValueKey('page $page'));

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  double scale = 1,
  ReadingTheme theme = ReadingTheme.paper,
  ThemeData? themeData,
}) async {
  tester.view
    ..physicalSize = Size(width, _height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: themeData ?? buildAppTheme(theme),
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Material(child: child),
    ),
  );
}

RenderSurahTextBlock _block(WidgetTester tester, [Finder? finder]) => tester
    .renderObject<RenderSurahTextBlock>(finder ?? find.byType(SurahTextBlock));

/// The selection's slice over [box]: its line's band, across the box.
Rect _slice(SurahParagraph paragraph, Rect box) {
  final band = paragraph.lineBands.singleWhere((b) => b.contains(box.center));
  return Rect.fromLTRB(box.left, band.top, box.right, band.bottom);
}

/// The block's first V2 block, after the first, whose shown lines end
/// inside an ayah (`cutAtEnd`) or start inside one, and that ayah.
(int, QuranAddress) _blockCutInsideAyah(
  SpikeSurahText surah, {
  required bool cutAtEnd,
}) {
  final planner = SurahFlowPlanner(
    surah: surah,
    width: 360,
    textScaler: const TextScaler.linear(1),
    pageMarkSize: _pageMark,
  );
  for (var k = 1; k < planner.all.length; k++) {
    final paragraph = planner.paragraphFor(planner.block(k)!);
    final start = paragraph.lineStartPositions.first;
    paragraph.dispose();
    if (start.offset > 0 &&
        start.offset < surah.ayat[start.ayah - 1].verbatim.length) {
      final ayah = QuranAddress(
        surah.firstAyah.riwaya,
        surah.firstAyah.surah,
        start.ayah,
      );
      return (cutAtEnd ? k - 1 : k, ayah);
    }
  }
  throw StateError('no block starts inside an ayah');
}

SpikeSurahText _first(SpikeSurahText surah, int ayat) => SpikeSurahText(
  firstAyah: surah.firstAyah,
  ayat: surah.ayat.sublist(0, ayat),
  words: surah.words.sublist(0, ayat),
  marks: surah.marks.sublist(0, ayat),
  basmala: surah.basmala,
  pageStarts: {
    for (final MapEntry(:key, :value) in surah.pageStarts.entries)
      if (key.ayah <= ayat) key: value,
  },
);

void main() {
  late Directory root;
  late SpikeSurahText long;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('s1_block');
    final read = await readSyntheticSurahs(root, withMarks: true);
    long = read.long;
    read.pack.close();
  });
  tearDownAll(() => root.delete(recursive: true));

  testWidgets('each AyahMarker sits on its placeholder, in reading order, '
      'and the markers take the sizes the planner assumes', (tester) async {
    for (final scale in [1.0, 2.0]) {
      final surah = _first(long, 60);
      await _pump(
        tester,
        SurahListV1(
          surah: surah,
          pageMark: _pageMarkOf,
          pageMarkSize: _pageMark,
        ),
        scale: scale,
      );
      final block = _block(tester);
      final origin = tester.getTopLeft(find.byType(SurahTextBlock));
      final paragraph = block.paragraph;
      for (var i = 0; i < surah.ayat.length; i++) {
        final marker = find.byWidgetPredicate(
          (w) => w is AyahMarker && w.number == i + 1,
        );
        expect(
          tester.getRect(marker),
          paragraph.markerRect(i).shift(origin),
          reason: 'marker ${i + 1} at ${scale}x',
        );
      }
      for (final MapEntry(key: ayah, value: page) in surah.pageStarts.entries) {
        expect(
          tester.getRect(find.byKey(ValueKey('page $page'))),
          paragraph.pageMarkRect(ayah.ayah - 1).shift(origin),
        );
      }
      expect(markOrderProblems(paragraph), isEmpty);
      final offline = surahParagraph(
        surah,
        width: 360,
        textScaler: TextScaler.linear(scale),
        pageMarkSize: _pageMark,
      );
      expect(paragraph.lineStartPositions, offline.lineStartPositions);
      offline.dispose();
    }
  });

  testWidgets('a tap on a word reports that word', (tester) async {
    final tapped = <QuranAddress>[];
    await _pump(
      tester,
      SurahListV1(
        surah: _first(long, 20),
        wrapBlock: (context, block) => BlockGestures(
          rule: TapRule.exact,
          onTap: (target) {
            if (target case WordTarget(:final word)) tapped.add(word);
          },
          child: block,
        ),
      ),
    );
    final block = _block(tester);
    final origin = tester.getTopLeft(find.byType(SurahTextBlock));
    final expected = <QuranAddress>[];
    for (final i in [0, 1, 2]) {
      final ayah = block.paragraph.content.ayahAt(i);
      for (final number in [1, long.words[i].length]) {
        final word = QuranAddress(ayah.riwaya, ayah.surah, ayah.ayah, number);
        final box = block.boxesOf(word).single;
        if (box.bottom + origin.dy > _height) continue;
        await tester.tapAt(origin + box.center);
        expected.add(word);
      }
    }
    expect(expected, isNotEmpty);
    expect(tapped, expected);

    tapped.clear();
    await tester.tapAt(origin + block.paragraph.markerRect(0).center);
    expect(tapped, isEmpty, reason: 'a marker is not a word');
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('highlights are painted from ${theme.name} tokens under the '
        'text, and the recited ayah fills its marker', (tester) async {
      final colors = AppColors.byId[theme.name]!;
      final ayah = QuranAddress(long.firstAyah.riwaya, long.firstAyah.surah, 2);
      final word = QuranAddress(ayah.riwaya, ayah.surah, 3, 2);
      await _pump(
        tester,
        SurahListV1(surah: _first(long, 10), highlighted: {ayah, word}),
        theme: theme,
      );
      final pattern = paints;
      for (final _ in _block(tester).boxesOf(ayah)) {
        pattern.rrect(color: colors.highlightAyah);
      }
      pattern
        ..rrect(color: colors.highlightWord)
        ..rect(color: colors.highlightWordLine)
        ..paragraph();
      expect(find.byType(SurahTextBlock), pattern);
      expect(
        tester
            .widgetList<AyahMarker>(find.byType(AyahMarker))
            .where((m) => m.playing)
            .map((m) => m.number),
        [2],
      );
    });
  }

  for (final theme in ReadingTheme.values) {
    testWidgets('a selected ayah is painted from ${theme.name} tokens over '
        'the ayah highlight, under the spoken word and the text, sliced '
        'across its lines, each slice as tall as its line', (tester) async {
      final colors = AppColors.byId[theme.name]!;
      QuranAddress ayahOf(int n) =>
          QuranAddress(long.firstAyah.riwaya, long.firstAyah.surah, n);
      final word = QuranAddress(
        long.firstAyah.riwaya,
        long.firstAyah.surah,
        3,
        2,
      );
      await _pump(tester, SurahListV1(surah: _first(long, 10)), theme: theme);
      final paragraph = _block(tester).paragraph;
      final selected = [
        for (var n = 1; n <= 10; n++) ayahOf(n),
      ].firstWhere((ayah) => paragraph.boxesOf(ayah).length >= 3);
      final recited = ayahOf(selected.ayah == 1 ? 2 : 1);
      final boxes = [
        for (final box in paragraph.boxesOf(selected)) _slice(paragraph, box),
      ];
      await _pump(
        tester,
        SurahListV1(
          surah: _first(long, 10),
          highlighted: {recited, word},
          selected: {selected},
        ),
        theme: theme,
      );
      const r = Radius.circular(AppRadius.radiusSm);
      final first = boxes.first;
      final middle = boxes[1];
      final last = boxes.last;
      final pattern = paints;
      for (final _ in paragraph.boxesOf(recited)) {
        pattern.rrect(color: colors.highlightAyah);
      }
      pattern
        ..rrect(
          color: colors.selection,
          rrect: RRect.fromRectAndCorners(
            Rect.fromLTRB(
              first.left,
              first.top,
              math.min(first.right + AppSpacing.space1, 360),
              first.bottom,
            ),
            topRight: r,
            bottomRight: r,
          ),
        )
        ..path(color: colors.selectionLine)
        ..rrect(
          color: colors.selection,
          rrect: RRect.fromRectAndCorners(middle),
        )
        ..path(color: colors.selectionLine);
      for (final _ in boxes.skip(3)) {
        pattern
          ..rrect(color: colors.selection)
          ..path(color: colors.selectionLine);
      }
      pattern
        ..rrect(
          color: colors.selection,
          rrect: RRect.fromRectAndCorners(
            Rect.fromLTRB(
              math.max(last.left - AppSpacing.space1, 0),
              last.top,
              last.right,
              last.bottom,
            ),
            topLeft: r,
            bottomLeft: r,
          ),
        )
        ..path(color: colors.selectionLine)
        ..rrect(color: colors.highlightWord)
        ..rect(color: colors.highlightWordLine)
        ..paragraph();
      expect(find.byType(SurahTextBlock), pattern);
    });
  }

  testWidgets('on a line that starts with the selected ayah\'s marker, the '
      'slice is as tall as the line, not the marker', (tester) async {
    final surah = _first(long, 60);
    for (final width in [360.0, 320.0, 412.0]) {
      await _pump(tester, SurahListV1(surah: surah), width: width);
      final paragraph = _block(tester).paragraph;
      final k = [for (var k = 1; k < paragraph.visibleLineCount; k++) k].where((
        k,
      ) {
        final start = paragraph.lineStartPositions[k];
        return start.offset == surah.ayat[start.ayah - 1].verbatim.length;
      }).firstOrNull;
      if (k == null) continue;
      final ayah = QuranAddress(
        surah.firstAyah.riwaya,
        surah.firstAyah.surah,
        paragraph.lineStartPositions[k].ayah,
      );
      final marker = paragraph.markerRect(paragraph.content.indexOf(ayah)!);
      final band = paragraph.lineBand(k);
      expect(band.contains(marker.center), isTrue);
      expect(marker.height, lessThan(band.height - 1));
      final slices = paragraph.boxesOf(ayah).length;
      await _pump(
        tester,
        SurahListV1(surah: surah, selected: {ayah}),
        width: width,
      );
      final pattern = paints;
      for (var i = 0; i < slices - 1; i++) {
        pattern.rrect(color: AppColors.paper.selection);
      }
      const r = Radius.circular(AppRadius.radiusSm);
      pattern.rrect(
        color: AppColors.paper.selection,
        rrect: RRect.fromRectAndCorners(
          Rect.fromLTRB(
            math.max(marker.left - AppSpacing.space1, 0),
            band.top,
            marker.right,
            band.bottom,
          ),
          topLeft: r,
          bottomLeft: r,
        ),
      );
      expect(find.byType(SurahTextBlock), pattern);
      return;
    }
    fail('no line starts with a marker at 320, 360 or 412');
  });

  testWidgets('the selection frame is 1.5 px inside the slice, and open '
      'where the ayah runs on to another line', (tester) async {
    await _pump(tester, SurahListV1(surah: _first(long, 10)));
    final paragraph = _block(tester).paragraph;
    final ayah = [
      for (var n = 1; n <= 10; n++)
        QuranAddress(long.firstAyah.riwaya, long.firstAyah.surah, n),
    ].firstWhere((ayah) => paragraph.boxesOf(ayah).length >= 3);
    await _pump(tester, SurahListV1(surah: _first(long, 10), selected: {ayah}));
    final middle = _slice(paragraph, paragraph.boxesOf(ayah)[1]);
    final y = middle.center.dy;
    expect(
      find.byType(SurahTextBlock),
      paints
        ..path()
        ..path(
          includes: [Offset(middle.center.dx, middle.top + 0.75)],
          excludes: [
            middle.center,
            Offset(middle.left + 0.75, y),
            Offset(middle.right - 0.75, y),
            Offset(middle.center.dx, middle.top + 2),
            Offset(middle.center.dx, middle.bottom - 0.75),
          ],
        ),
    );
  });

  test('between two selected lines one 1.5 px line is drawn, the lower '
      'slice\'s top, and the upper slice keeps its bottom line where '
      'nothing lies below it', () async {
    const scale = 2.0;
    const width = 360.0;
    const band = 58.0;
    const colors = AppColors.paper;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    paintHighlights(
      canvas,
      Offset.zero,
      colors: colors,
      selected: [
        (
          boxes: const [
            Rect.fromLTRB(0, 0, 200, band),
            Rect.fromLTRB(150, band, width, 2 * band),
          ],
          starts: true,
          ends: true,
        ),
      ],
      width: width,
    );
    final image = recorder.endRecording().toImageSync(
      (width * scale).toInt(),
      (2 * band * scale).toInt(),
    );
    addTearDown(image.dispose);
    final bytes = (await image.toByteData())!;
    Color pixel(int x, int y) {
      final i = (y * image.width + x) * 4;
      return Color.fromARGB(
        bytes.getUint8(i + 3),
        bytes.getUint8(i),
        bytes.getUint8(i + 1),
        bytes.getUint8(i + 2),
      );
    }

    /// The device rows of column [x], around the line between the slices,
    /// painted in the frame's colour.
    List<int> lineRows(double x) => [
      for (var y = ((band - 6) * scale).toInt(); y < (band + 6) * scale; y++)
        if (pixel((x * scale).toInt(), y) == colors.selectionLine) y,
    ];
    const edge = band * scale;
    const line = 1.5 * scale;
    final top = [for (var y = edge; y < edge + line; y++) y.toInt()];
    final bottom = [for (var y = edge - line; y < edge; y++) y.toInt()];
    expect(lineRows(175), top, reason: 'under both slices');
    expect(lineRows(300), top, reason: 'only the lower slice');
    expect(lineRows(75), bottom, reason: 'only the upper slice');
    expect(pixel(175 * 2, (edge - 1).toInt()), colors.selection);
  });

  testWidgets('a selected ayah that runs on from the block before is open '
      'there: no padding, frame side or corners', (tester) async {
    final surah = _first(long, 60);
    final (k, ayah) = _blockCutInsideAyah(surah, cutAtEnd: false);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      PageBlocksV2(
        surah: surah,
        pageMark: _pageMarkOf,
        pageMarkSize: _pageMark,
        controller: controller,
        selected: {ayah},
        blockKey: (k) => ValueKey('block $k'),
      ),
    );
    final finder = find.byKey(ValueKey('block $k'));
    while (finder.evaluate().isEmpty) {
      controller.jumpTo(controller.offset + _height / 2);
      await tester.pump();
    }
    final paragraph = _block(tester, finder).paragraph;
    final boxes = paragraph.boxesOf(ayah);
    expect(paragraph.topOf(ayah), isNull, reason: 'starts before the block');
    final ends = paragraph.isVisible(
      paragraph.markerRect(paragraph.content.indexOf(ayah)!),
    );
    const r = Radius.circular(AppRadius.radiusSm);
    final first = _slice(paragraph, boxes.first);
    expect(
      finder,
      paints..rrect(
        color: AppColors.paper.selection,
        rrect: boxes.length == 1 && ends
            ? RRect.fromRectAndCorners(
                Rect.fromLTRB(
                  math.max(first.left - AppSpacing.space1, 0),
                  first.top,
                  first.right,
                  first.bottom,
                ),
                topLeft: r,
                bottomLeft: r,
              )
            : RRect.fromRectAndCorners(first),
      ),
    );
  });

  for (final scale in [1.0, 2.0]) {
    for (final width in [320.0, 360.0, 412.0]) {
      testWidgets('marked V1 and V2 build at ${width.toInt()}, ${scale}x, and '
          'every V2 block that hides or moves a line recolours it', (
        tester,
      ) async {
        await _pump(
          tester,
          SurahListV1(
            surah: long,
            pageMark: _pageMarkOf,
            pageMarkSize: _pageMark,
          ),
          width: width,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        expect(markOrderProblems(_block(tester).paragraph), isEmpty);
        final seen = await _scrollV2(
          tester,
          _first(long, 120),
          width: width,
          scale: scale,
        );
        expect(seen.values.where((b) => b.leadIn > 0), isNotEmpty);
        expect(seen.values.where((b) => b.cut), isNotEmpty);
        for (final MapEntry(key: k, value: block) in seen.entries) {
          if (block.leadIn > 0 || block.cut || block.shifted) {
            expect(block.recoloured, isTrue, reason: 'block $k');
          }
        }
      });
    }
  }

  testWidgets('searching down from 360, V2 blocks whose paragraph or cut '
      'line starts at a mark are found, built and recoloured', (tester) async {
    final surah = _first(long, 150);
    const scaler = TextScaler.linear(1);
    bool atMark(LineStart start) =>
        surah.marks[start.ayah - 1].any((m) => m.start == start.offset);
    ({double width, int block})? startsAtMark;
    ({double width, int block})? cutsAtMark;
    for (
      var width = 360.0;
      width > 320 && (startsAtMark == null || cutsAtMark == null);
      width--
    ) {
      final planner = SurahFlowPlanner(
        surah: surah,
        width: width,
        textScaler: scaler,
        pageMarkSize: _pageMark,
      );
      for (final (k, block) in planner.all.indexed) {
        final paragraph = planner.paragraphFor(block, planning: true);
        final starts = paragraph.lineStartPositions;
        paragraph.dispose();
        if (startsAtMark == null &&
            block.startOffset > 0 &&
            atMark(starts[0])) {
          startsAtMark = (width: width, block: k);
        }
        final shown = block.maxLines;
        if (cutsAtMark == null &&
            shown != null &&
            atMark(starts[block.leadIn + shown])) {
          cutsAtMark = (width: width, block: k);
        }
      }
    }
    // ignore: avoid_print
    print(
      'V2 block starting at a mark: $startsAtMark; cut at a mark: '
      '$cutsAtMark',
    );
    expect(startsAtMark, isNotNull);
    expect(cutsAtMark, isNotNull);
    for (final found in [startsAtMark!, cutsAtMark!]) {
      final seen = await _scrollV2(
        tester,
        surah,
        width: found.width,
        scale: 1,
        until: found.block,
      );
      expect(seen[found.block]!.recoloured, isTrue);
    }
  });

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('V1 reflows at 200% in ${width.toInt()} wide with nothing '
        'outside the width', (tester) async {
      await _pump(
        tester,
        SurahListV1(
          surah: long,
          pageMark: _pageMarkOf,
          pageMarkSize: _pageMark,
        ),
        width: width,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      final block = _block(tester);
      expect(block.size.width, width);
      for (final marker in tester.widgetList<AyahMarker>(
        find.byType(AyahMarker),
      )) {
        final rect = tester.getRect(find.byWidget(marker));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      }
      expect(markOrderProblems(block.paragraph), isEmpty);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('V2 blocks, built as the list scrolls, stack into the lines '
        'of V1 at ${scale}x', (tester) async {
      final surah = _first(long, 120);
      final v1 = surahParagraph(
        surah,
        width: 360,
        textScaler: TextScaler.linear(scale),
        pageMarkSize: _pageMark,
      );
      addTearDown(v1.dispose);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        PageBlocksV2(
          surah: surah,
          pageMark: _pageMarkOf,
          pageMarkSize: _pageMark,
          controller: controller,
          blockKey: (k) => ValueKey('block $k'),
        ),
        scale: scale,
      );
      final listTop = tester.getTopLeft(find.byType(ListView)).dy;
      final lines = <int, ({LineStart start, double top})>{};
      final firstLine = <int, int>{};
      var notBuilt = false;
      while (true) {
        expect(tester.takeException(), isNull);
        for (var k = 0; k < 40; k++) {
          final finder = find.byKey(ValueKey('block $k'));
          if (finder.evaluate().isEmpty) {
            if (k > 0 && firstLine.containsKey(k - 1)) notBuilt = true;
            continue;
          }
          final paragraph = _block(tester, finder).paragraph;
          expect(markOrderProblems(paragraph), isEmpty);
          final top =
              tester.getTopLeft(finder).dy - listTop + controller.offset;
          final first = firstLine[k] ??= k == 0
              ? 0
              : firstLine[k - 1]! +
                    _block(
                      tester,
                      find.byKey(ValueKey('block ${k - 1}')),
                    ).paragraph.visibleLineCount;
          for (final (j, start) in paragraph.lineStartPositions.indexed) {
            lines[first + j] = (
              start: start,
              top: paragraph.lineBands[j].top + top,
            );
          }
        }
        if (controller.offset >= controller.position.maxScrollExtent) break;
        controller.jumpTo(
          (controller.offset + _height / 2).clamp(
            0,
            controller.position.maxScrollExtent,
          ),
        );
        await tester.pump();
      }
      expect(notBuilt, isTrue, reason: 'blocks past the viewport wait');
      final v1Starts = v1.lineStartPositions;
      final v1Bands = v1.lineBands;
      expect(lines.keys.toSet(), {for (var i = 0; i < v1.lineCount; i++) i});
      for (final MapEntry(key: line, value: drawn) in lines.entries) {
        expect(drawn.start, v1Starts[line], reason: 'line $line');
        expect(
          drawn.top,
          moreOrLessEquals(v1Bands[line].top, epsilon: 0.01),
          reason: 'line $line sits where V1 draws it',
        );
      }
    });
  }

  testWidgets(
    'V2 hides the lines it lays out past its last one, also from semantics',
    (tester) async {
      await _pump(
        tester,
        PageBlocksV2(
          surah: _first(long, 40),
          wrapBlock: (context, block) =>
              BlockGestures(rule: TapRule.exact, onTap: (_) {}, child: block),
          blockKey: (k) => ValueKey('block $k'),
        ),
      );
      final block = _block(tester, find.byKey(const ValueKey('block 0')));
      final paragraph = block.paragraph;
      expect(paragraph.visibleLineCount, lessThan(paragraph.lineCount));
      expect(paragraph.recoloured, isTrue);
      expect(block.size.height, paragraph.lineBands.last.bottom);
      final last = paragraph.content.length - 1;
      expect(paragraph.isVisible(paragraph.markerRect(last)), isFalse);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is AyahMarker &&
              w.number == paragraph.content.ayahAt(last).ayah,
        ),
        findsWidgets,
        reason: 'built, laid out, but neither painted nor hit',
      );
      final inSemantics = <RenderObject>[];
      block.visitChildrenForSemantics(inSemantics.add);
      expect(inSemantics.length, lessThan(block.childCount));
      expect(inSemantics, isNot(contains(block.lastChild)));
    },
  );

  test('the engine still orders two placeholders on a right-to-left line '
      'left to right (Flutter 3.44.7); SurahParagraph reassigns slots', () {
    final ayah = long.ayat[5];
    final painter = TextPainter(
      text: TextSpan(
        style: quranPageStyle,
        children: [
          TextSpan(text: ayah.verbatim),
          _probe,
          TextSpan(text: ayah.verbatim),
          _probe,
          TextSpan(text: ayah.verbatim),
        ],
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.justify,
    );
    addTearDown(painter.dispose);
    final length = ayah.verbatim.length;
    painter
      ..setPlaceholderDimensions(const [
        PlaceholderDimensions(
          size: Size(20, 20),
          alignment: ui.PlaceholderAlignment.middle,
        ),
        PlaceholderDimensions(
          size: Size(60, 20),
          alignment: ui.PlaceholderAlignment.middle,
        ),
      ])
      ..layout(minWidth: 100000, maxWidth: 100000);
    Rect box(int at) => painter
        .getBoxesForSelection(
          TextSelection(baseOffset: at, extentOffset: at + 1),
        )
        .single
        .toRect();
    final first = box(length);
    final second = box(2 * length + 1);
    expect(first.top, second.top, reason: 'one line');
    // Right to left, the first placeholder should be the right one.
    expect(first.left, lessThan(second.left));
  });
}

const WidgetSpan _probe = WidgetSpan(child: SizedBox.shrink());

typedef _SeenBlock = ({int leadIn, bool cut, bool shifted, bool recoloured});

/// Pumps V2 of [surah] and scrolls it to its end, or until block [until]
/// is built, with no exception on the way; what each block built did.
Future<Map<int, _SeenBlock>> _scrollV2(
  WidgetTester tester,
  SpikeSurahText surah, {
  required double width,
  required double scale,
  int? until,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await _pump(
    tester,
    PageBlocksV2(
      surah: surah,
      pageMark: _pageMarkOf,
      pageMarkSize: _pageMark,
      controller: controller,
      blockKey: (k) => ValueKey('block $k'),
    ),
    width: width,
    scale: scale,
  );
  final seen = <int, _SeenBlock>{};
  while (true) {
    expect(tester.takeException(), isNull);
    for (final element in find.byType(SurahTextBlock).evaluate()) {
      final key = (element.widget.key! as ValueKey<String>).value;
      final paragraph =
          (element.renderObject! as RenderSurahTextBlock).paragraph;
      seen[int.parse(key.split(' ').last)] = (
        leadIn: paragraph.firstShownLine,
        cut:
            paragraph.firstShownLine + paragraph.visibleLineCount <
            paragraph.lineCount,
        shifted: paragraph.lastLineShift != 0,
        recoloured: paragraph.recoloured,
      );
    }
    if (until != null && seen.containsKey(until)) return seen;
    if (controller.offset >= controller.position.maxScrollExtent) break;
    controller.jumpTo(
      (controller.offset + _height / 2).clamp(
        0,
        controller.position.maxScrollExtent,
      ),
    );
    await tester.pump();
  }
  expect(until, isNull, reason: 'block $until was never built');
  return seen;
}
