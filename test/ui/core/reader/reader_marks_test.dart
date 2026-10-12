import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/margin_mark.dart';
import 'package:holyquran/ui/core/reader/reader_style.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';

import '../../../../testing/golden.dart';
import 'reader_fixture.dart';

const _sizes = [
  (width: 360.0, system: 1.0, step: 1.0),
  (width: 360.0, system: 2.0, step: 1.0),
  (width: 320.0, system: 2.0, step: 2.0),
];

List<BlockLayout> _laidOut(SurahLayout plan) => [
  for (var b = 0; b < plan.blocks.length; b++)
    BlockLayout(plan, b, ink: AppColors.paper.quranInk),
];

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('reader_marks');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  test('page marks come from the page divisions inside the surah', () {
    expect(fixture.surahs[longSurah]!.pageStarts, {7: 3, 15: 4, 23: 5, 31: 6});
    expect(fixture.surahs[overwideSurah]!.pageStarts, isEmpty);
  });

  for (final size in _sizes) {
    final name = '${size.width}/${size.system}x/${size.step}';

    test('each page mark sits in the line before its ayah, $name', () {
      final surah = fixture.surahs[longSurah]!;
      final plan = SurahLayout.plan(
        surah,
        ReaderStyle(
          ReaderTextScaler(TextScaler.linear(size.system), size.step),
        ),
        size.width,
      );
      final blocks = _laidOut(plan);
      for (final MapEntry(key: ayah, value: page) in surah.pageStarts.entries) {
        final holders = [
          for (final block in blocks)
            if (block.pageMarks[ayah] == page) block,
        ];
        expect(holders, hasLength(1), reason: 'page $page');
        final block = holders.single;
        final mark = block.pageMarkRect(ayah)!;
        final line = (mark.center.dy / plan.lineHeight).floor();
        expect(line + block.block.firstLine, plan.lineOfAyah(ayah));
        final word = blocks
            .map((b) => b.wordBox(ayah, 1))
            .whereType<Rect>()
            .single;
        final sameLine =
            identical(
              blocks.firstWhere((b) => b.wordBox(ayah, 1) != null),
              block,
            ) &&
            word.center.dy ~/ plan.lineHeight == line;
        if (sameLine) {
          expect(mark.left, greaterThanOrEqualTo(word.right - 0.5));
        }
        if (block.markerRect(ayah - 1) case final before?
            when before.center.dy ~/ plan.lineHeight == line) {
          expect(mark.right, lessThanOrEqualTo(before.left + 0.5));
        }
      }
      for (final block in blocks) {
        block.dispose();
      }
    });

    test('markers sharing a line keep reading order, $name', () {
      for (final surah in fixture.surahs.values) {
        final plan = SurahLayout.plan(
          surah,
          ReaderStyle(
            ReaderTextScaler(TextScaler.linear(size.system), size.step),
          ),
          size.width,
        );
        for (final block in _laidOut(plan)) {
          final ayat = block.ayat.toList();
          for (var k = 0; k + 1 < ayat.length; k++) {
            final a = block.markerRect(ayat[k])!;
            final b = block.markerRect(ayat[k + 1])!;
            if ((a.center.dy - b.center.dy).abs() < 1) {
              expect(a.left, greaterThan(b.right - 0.5));
            } else {
              expect(b.top, greaterThan(a.top));
            }
            for (final word in block.plan.text.ayat[ayat[k]].words) {
              final box = block.wordBox(ayat[k] + 1, word.number);
              if (box == null || (box.center.dy - a.center.dy).abs() > 1) {
                continue;
              }
              expect(box.left, greaterThanOrEqualTo(a.right - 0.5));
            }
          }
          block.dispose();
        }
      }
    });
  }

  test('SkParagraph still reverses placeholders on a right-to-left line', () {
    // S1 finding 1. If this fails, the engine was fixed and the slot
    // reassignment in BlockLayout may be removed.
    final builder =
        ui.ParagraphBuilder(ReaderStyle(TextScaler.noScaling).paragraphStyle())
          ..addPlaceholder(20, 20, ui.PlaceholderAlignment.middle)
          ..addPlaceholder(20, 20, ui.PlaceholderAlignment.middle);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 300));
    final boxes = paragraph.getBoxesForPlaceholders();
    expect(boxes.first.left, lessThan(boxes.last.left));
    paragraph.dispose();
  });

  test('margin marks: the largest division at its first ayah, and sajdas', () {
    expect(fixture.surahs[longSurah]!.marginMarks, const [
      MarginMark(MarginMarkKind.rub, 5, hizb: 1, quarter: 1),
      MarginMark(MarginMarkKind.hizb, 10, hizb: 2),
      MarginMark(MarginMarkKind.rub, 15, hizb: 2, quarter: 1),
      MarginMark(MarginMarkKind.juz, 20, juz: 2),
      MarginMark(MarginMarkKind.rub, 25, hizb: 3, quarter: 1),
      MarginMark(MarginMarkKind.hizb, 30, hizb: 4),
      MarginMark(MarginMarkKind.rub, 35, hizb: 4, quarter: 1),
      MarginMark(MarginMarkKind.sajda, sajdaAyah),
    ]);
  });

  test('each margin mark is anchored to its line', () {
    final surah = fixture.surahs[longSurah]!;
    final plan = SurahLayout.plan(
      surah,
      ReaderStyle(const ReaderTextScaler(TextScaler.noScaling, 1)),
      360,
    );
    final anchored = <MarginMark>[];
    for (final block in _laidOut(plan)) {
      for (final (mark, band) in block.marginMarks) {
        anchored.add(mark);
        final line = band.top ~/ plan.lineHeight + block.block.firstLine;
        expect(
          line,
          mark.kind == MarginMarkKind.sajda
              ? plan.lineOfAyahEnd(mark.ayah)
              : plan.lineOfAyahText(mark.ayah),
        );
        expect(band.height, plan.lineHeight);
      }
      block.dispose();
    }
    expect(anchored, unorderedEquals(surah.marginMarks));
  });

  testWidgets('margin marks read as the identity writes them', (tester) async {
    Future<void> show(MarginMark mark) =>
        tester.pumpWidget(goldenApp(ReadingTheme.paper, MarginMarkView(mark)));
    final strings = lookupAppLocalizations(const Locale('ar'));
    await show(const MarginMark(MarginMarkKind.rub, 5, hizb: 3, quarter: 1));
    expect(
      find.text('${strings.rubLabel}\n${strings.hizbLabel(arabicDigits(3))}'),
      findsOneWidget,
    );
    expect(find.byType(StarOutline), findsOneWidget);
    // The identity names only the first quarter; the half and the three
    // quarters show the star alone until the owner gives words.
    await show(const MarginMark(MarginMarkKind.rub, 7, hizb: 3, quarter: 2));
    expect(find.byType(Text), findsNothing);
    expect(find.byType(StarOutline), findsOneWidget);
    await show(const MarginMark(MarginMarkKind.hizb, 10, hizb: 2));
    expect(find.text(strings.hizbLabel(arabicDigits(2))), findsOneWidget);
    expect(find.byType(StarOutline), findsOneWidget);
    await show(const MarginMark(MarginMarkKind.juz, 20, juz: 12));
    expect(find.text(strings.juzLabel(arabicDigits(12))), findsOneWidget);
    expect(find.byType(StarOutline), findsNothing);
    await show(const MarginMark(MarginMarkKind.sajda, 12));
    expect(find.text(strings.sajdaLabel), findsOneWidget);
    expect(find.byType(StarOutline), findsNothing);
  });
}
