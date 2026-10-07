import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import 'page_blocks_v2.dart';
import 'render_checks.dart';
import 'spike_surah_text.dart';
import 'surah_list_v1.dart';
import 'surah_paragraph.dart';
import 'surah_text_block.dart';
import 'synthetic_surah_pack.dart';

// Every text is Arabic-script nonsense from the spike writer's pack, read
// through the app's verification and text repository.

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
}) async {
  tester.view
    ..physicalSize = Size(width, _height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(theme),
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

SpikeSurahText _first(SpikeSurahText surah, int ayat) => SpikeSurahText(
  firstAyah: surah.firstAyah,
  ayat: surah.ayat.sublist(0, ayat),
  words: surah.words.sublist(0, ayat),
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
    final read = await readSyntheticSurahs(root);
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
      SurahListV1(surah: _first(long, 20), onWordTap: tapped.add),
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
      final tapped = <QuranAddress>[];
      await _pump(
        tester,
        PageBlocksV2(
          surah: _first(long, 40),
          onWordTap: tapped.add,
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
