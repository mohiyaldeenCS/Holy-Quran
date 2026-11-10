import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/metrics/reader_screen_metrics.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/line_breaker.dart';
import 'package:holyquran/ui/core/reader/reader_paragraph.dart';
import 'package:holyquran/ui/core/reader/reader_style.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/reader/tap_resolver.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'reader_fixture.dart';

const _ink = AppColors.paper;

/// The widths and scales the spike measured at, and a narrow phone at the
/// largest reader step on top of the largest system scale.
const _cases = [
  (width: 360.0, system: 1.0, step: 1.0),
  (width: 412.0, system: 1.0, step: 1.0),
  (width: 360.0, system: 2.0, step: 1.0),
  (width: 320.0, system: 2.0, step: 2.0),
];

ReaderStyle _style(double system, double step) =>
    ReaderStyle(ReaderTextScaler(TextScaler.linear(system), step));

/// A row of margin marks as tall as a synthetic measure says: taller for
/// more marks, so that rows differ.
double _rowHeight(List<MarginMark> marks) => 17.0 + 9 * marks.length;

/// A row taller than any ink that leaves a line, in whole pixels.
const double _tallRow = 200;

List<BlockLayout> _laidOut(SurahLayout plan) => [
  for (var b = 0; b < plan.blocks.length; b++)
    BlockLayout(plan, b, ink: _ink.quranInk),
];

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('surah_layout');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  for (final size in _cases) {
    final name = '${size.width}/${size.system}x/${size.step}';

    test('every ayah drawn rejoins to its stored bytes, $name', () {
      for (final MapEntry(key: number, value: surah)
          in fixture.surahs.entries) {
        final plan = SurahLayout.plan(
          surah,
          _style(size.system, size.step),
          size.width,
        );
        final drawn = <int, StringBuffer>{};
        for (final segment in plan.segments) {
          for (final run in segmentRuns(
            plan.plannedAyat(segment),
            plan.style,
            colourOfLine: (_) => _ink.quranInk,
          )) {
            if (run is TextRun) {
              (drawn[run.ayah] ??= StringBuffer()).write(run.text);
            }
          }
        }
        final stored = fixture.pack.raw.ayat(number);
        expect(drawn.keys, [for (final (ayah, _) in stored) ayah]);
        for (final (ayah, bytes) in stored) {
          expect(
            utf8.encode(drawn[ayah].toString()),
            bytes,
            reason: 'surah $number ayah $ayah',
          );
        }
      }
    });

    test('the paragraphs break where the plan does, $name', () {
      for (final surah in fixture.surahs.values) {
        final plan = SurahLayout.plan(
          surah,
          _style(size.system, size.step),
          size.width,
        );
        for (final block in _laidOut(plan)) {
          expect(
            block.laidLineStarts,
            block.plannedLineStarts,
            reason: 'surah ${surah.surah} block ${block.index}',
          );
          expect(block.matchesPlan, isTrue);
          block.dispose();
        }
      }
    });

    test('no line starts with a mark cut from its word, $name', () {
      for (final surah in fixture.surahs.values) {
        final plan = SurahLayout.plan(
          surah,
          _style(size.system, size.step),
          size.width,
        );
        for (final block in _laidOut(plan)) {
          for (final start in block.laidLineStarts) {
            final ayah = surah.ayat[start.ayah];
            final allowed = {-1, 0, for (final word in ayah.words) word.start};
            expect(
              allowed,
              contains(start.offset),
              reason: 'surah ${surah.surah} ayah ${start.ayah + 1}',
            );
            expect(
              ayah.marks.map((mark) => mark.start),
              isNot(contains(start.offset)),
            );
          }
          block.dispose();
        }
      }
    });

    test('blocks break their lines as one block does, $name', () {
      final surah = fixture.surahs[longSurah]!;
      final style = _style(size.system, size.step);
      final blocks = SurahLayout.plan(surah, style, size.width, blockLines: 6);
      final whole = SurahLayout.plan(
        surah,
        style,
        size.width,
        blockLines: 1 << 30,
      );
      expect(whole.blocks, hasLength(1));
      expect(blocks.blocks.length, greaterThan(2));
      final laid = _laidOut(blocks);
      final split = [for (final block in laid) ...block.laidLineStarts];
      final one = _laidOut(whole).single;
      expect(split, one.laidLineStarts);
      expect(split, [
        for (var line = 0; line < whole.lines.length; line++)
          whole.lineStart(line),
      ]);
      one.dispose();
      for (final block in laid) {
        block.dispose();
      }
    });

    test('lines fit their width and every line is one height, $name', () {
      for (final surah in fixture.surahs.values) {
        final plan = SurahLayout.plan(
          surah,
          _style(size.system, size.step),
          size.width,
        );
        final hang = plan.style.markGap;
        expect(
          plan.lines.every(
            (line) =>
                line.natural - (line.endsWithSlot ? hang : 0) <= size.width,
          ),
          isTrue,
        );
        for (final block in _laidOut(plan)) {
          for (final (k, (left, right)) in block.laidLineExtents.indexed) {
            final line = plan.lines[block.block.firstLine + k];
            expect(right, lessThanOrEqualTo(size.width + 0.5));
            expect(left, greaterThanOrEqualTo(-overhangOf(line, hang) - 0.5));
          }
          for (final ayah in block.ayat) {
            if (block.pageMarkRect(ayah) case final mark?) {
              // A page mark's slot may hang past the edge; its middle may not.
              expect(mark.center.dx, inInclusiveRange(0, size.width));
            }
            for (final box in [
              ...block.ayahBoxes(ayah),
              block.markerRect(ayah)!,
            ]) {
              expect(box.left, greaterThanOrEqualTo(-0.01));
              expect(box.right, lessThanOrEqualTo(size.width + 0.01));
              expect(box.top, greaterThanOrEqualTo(-0.01));
              expect(box.bottom, lessThanOrEqualTo(block.height + 0.01));
            }
          }
          block.dispose();
        }
      }
    });

    test('justified lines reach both edges, $name', () {
      for (final surah in fixture.surahs.values) {
        final plan = SurahLayout.plan(
          surah,
          _style(size.system, size.step),
          size.width,
        );
        for (final block in _laidOut(plan)) {
          final ink = <int, List<Rect>>{};
          void add(Rect rect) =>
              (ink[rect.center.dy ~/ plan.lineHeight] ??= []).add(rect);
          for (final ayah in block.ayat) {
            for (final word in surah.ayat[ayah - 1].words) {
              if (block.wordBox(ayah, word.number) case final box?) add(box);
            }
            for (final mark in surah.ayat[ayah - 1].marks) {
              block.markBoxes(ayah, mark.number).forEach(add);
            }
            add(block.markerRect(ayah)!);
          }
          for (var k = 0; k < block.lineCount; k++) {
            final line = plan.lines[block.block.firstLine + k];
            final last = block.block.firstLine + k == plan.lines.length - 1;
            final stretchable = line.gaps + line.slots > 0;
            final edges =
                plan.lineStart(block.block.firstLine + k).offset >= 0 &&
                block.pageMarkRect(line.end.ayah + 1) == null;
            if (last || !stretchable || !edges || ink[k] == null) continue;
            final right = ink[k]!.map((r) => r.right).reduce(math.max);
            final left = ink[k]!.map((r) => r.left).reduce(math.min);
            expect(right, closeTo(size.width, 1), reason: 'line $k');
            expect(left, closeTo(0, 1), reason: 'line $k');
          }
          block.dispose();
        }
      }
    });

    test('margin rows move lines down and change nothing across, $name', () {
      for (final surah in fixture.surahs.values) {
        final style = _style(size.system, size.step);
        final plain = SurahLayout.plan(surah, style, size.width);
        final plan = SurahLayout.plan(
          surah,
          style,
          size.width,
          marginRow: _rowHeight,
        );
        final reason = 'surah ${surah.surah}';
        expect(plan.lineHeight, plain.lineHeight);
        expect(plan.lines, hasLength(plain.lines.length));
        for (final (k, line) in plan.lines.indexed) {
          final before = plain.lines[k];
          expect(
            (line.start, line.end, line.stretch),
            (before.start, before.end, before.stretch),
            reason: '$reason line $k',
          );
        }
        expect(
          [for (final s in plan.segments) (s.firstLine, s.endLine)],
          [for (final s in plain.segments) (s.firstLine, s.endLine)],
        );
        final rowLines = {
          for (final mark in surah.marginMarks) plan.lineOfAyahText(mark.ayah),
        };
        var below = 0.0;
        for (var k = 0; k < plan.lines.length; k++) {
          final row = plan.rowExtent(k);
          if (rowLines.contains(k)) {
            expect(
              row,
              _rowHeight(plan.marksAbove(k)) + ReaderScreenMetrics.marginRowGap,
            );
          } else {
            expect(row, 0, reason: '$reason line $k');
          }
          below += row;
          expect(plan.lineTop(k), closeTo(plain.lineTop(k) + below, 1e-6));
          expect(plan.lineAt(plan.slotTop(k)), k);
          expect(plan.lineAt(plan.lineTop(k) + 1), k);
        }
        expect(plan.height, closeTo(plain.height + below, 1e-6));

        final blocks = _laidOut(plan);
        final plainBlocks = _laidOut(plain);
        expect(blocks, hasLength(plainBlocks.length));
        for (final (b, block) in blocks.indexed) {
          final was = plainBlocks[b];
          expect(block.matchesPlan, isTrue, reason: '$reason block $b');
          expect(block.laidLineStarts, was.laidLineStarts);
          expect(block.laidLineExtents, was.laidLineExtents);
          final drop = [
            for (var line = 0; line < block.lineCount; line++)
              block.lineBand(line).top - was.lineBand(line).top,
          ];
          Rect moved(Rect rect) {
            final line = was.lineBands.indexWhere(
              (band) =>
                  band.top <= rect.center.dy && rect.center.dy < band.bottom,
            );
            return rect.translate(0, drop[line]);
          }

          void same(Rect? now, Rect? before, String what) {
            expect(now == null, before == null, reason: what);
            if (now == null || before == null) return;
            final expected = moved(before);
            expect(now.left, closeTo(expected.left, 1e-6), reason: what);
            expect(now.right, closeTo(expected.right, 1e-6), reason: what);
            expect(now.top, closeTo(expected.top, 1e-6), reason: what);
            expect(now.bottom, closeTo(expected.bottom, 1e-6), reason: what);
          }

          for (final ayah in block.ayat) {
            final what = '$reason ayah $ayah';
            same(block.markerRect(ayah), was.markerRect(ayah), '$what marker');
            same(block.pageMarkRect(ayah), was.pageMarkRect(ayah), what);
            final boxes = block.ayahBoxes(ayah);
            final before = was.ayahBoxes(ayah);
            expect(boxes, hasLength(before.length), reason: what);
            for (final (k, box) in boxes.indexed) {
              same(box, before[k], '$what box $k');
            }
            final lines = block.ayahLines(ayah);
            expect(lines, hasLength(was.ayahLines(ayah).length));
            for (final (k, line) in lines.indexed) {
              same(line, was.ayahLines(ayah)[k], '$what line $k');
            }
            expect(
              block.ayahRect(ayah),
              before.map(moved).reduce((a, b) => a.expandToInclude(b)),
              reason: what,
            );
            expect(block.topOfAyah(ayah), moved(was.ayahBoxes(ayah).first).top);
            for (final word in surah.ayat[ayah - 1].words) {
              final box = block.wordBox(ayah, word.number);
              same(box, was.wordBox(ayah, word.number), '$what w$word');
              if (box == null) continue;
              expect(
                targetInBlock(block, box.center),
                targetInBlock(was, was.wordBox(ayah, word.number)!.center),
                reason: '$what word ${word.number}',
              );
            }
            for (final mark in surah.ayat[ayah - 1].marks) {
              final boxes = block.markBoxes(ayah, mark.number);
              final before = was.markBoxes(ayah, mark.number);
              expect(boxes, hasLength(before.length));
              for (final (k, box) in boxes.indexed) {
                same(box, before[k], '$what mark ${mark.number}');
              }
            }
          }
          for (final (marks, row) in block.marginRows) {
            final line =
                plan.lineOfAyahText(marks.first.ayah) - block.block.firstLine;
            expect(
              row.bottom,
              block.lineBand(line).top - ReaderScreenMetrics.marginRowGap,
            );
            for (final band in block.lineBands) {
              expect(row.overlaps(band), isFalse, reason: reason);
            }
          }
          expect(
            block.height,
            closeTo(
              was.height +
                  [
                    for (
                      var l = block.block.firstLine;
                      l < block.block.endLine;
                      l++
                    )
                      plan.rowExtent(l),
                  ].fold(0.0, (a, b) => a + b),
              1e-6,
            ),
          );
        }
        for (final block in [...blocks, ...plainBlocks]) {
          block.dispose();
        }
      }
    });

    test('the surah ends on a centred line, $name', () {
      for (final surah in fixture.surahs.values) {
        final plan = SurahLayout.plan(
          surah,
          _style(size.system, size.step),
          size.width,
        );
        final blocks = _laidOut(plan);
        final last = blocks.last;
        final lastAyah = surah.ayat.length;
        final band = last.lineBand(last.lineCount - 1);
        final ink = [
          for (final ayah in last.ayat)
            ...last.ayahBoxes(ayah).where((box) => box.center.dy > band.top),
        ];
        final marker = last.markerRect(lastAyah)!;
        final left = marker.left;
        final right = ink
            .map((box) => box.right)
            .reduce((a, b) => a > b ? a : b);
        expect((left + right) / 2, closeTo(size.width / 2, 1));
        for (final block in blocks) {
          block.dispose();
        }
      }
    });
  }

  test('lines below a row are drawn where their boxes are, the centred last '
      'line too', () async {
    Future<Uint8List> pixels(BlockLayout block) async {
      final recorder = ui.PictureRecorder();
      block.paint(Canvas(recorder), Offset.zero);
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        block.width.ceil(),
        block.height.ceil(),
      );
      final bytes = await image.toByteData();
      image.dispose();
      picture.dispose();
      return bytes!.buffer.asUint8List();
    }

    var lastLineMoved = false;
    var compared = 0;
    for (final surah in fixture.surahs.values) {
      // A row at every other ayah, far taller than any ink that leaves a
      // line, so that each run of lines between rows stands apart.
      final marked = SurahText(
        riwaya: surah.riwaya,
        surah: surah.surah,
        ayat: surah.ayat,
        basmala: surah.basmala,
        pageStarts: surah.pageStarts,
        marginMarks: [
          for (var a = 2; a <= surah.ayat.length; a += 2)
            MarginMark(MarginMarkKind.sajda, a),
        ],
      );
      final style = _style(1, 1);
      final plain = SurahLayout.plan(marked, style, 360);
      final plan = SurahLayout.plan(
        marked,
        style,
        360,
        marginRow: (_) => _tallRow,
      );
      final last = plan.segments.last;
      for (var line = last.firstLine + 1; line < last.endLine; line++) {
        if (plan.rowExtent(line) > 0) lastLineMoved = true;
      }
      for (var b = 0; b < plan.blocks.length; b++) {
        final now = BlockLayout(plan, b, ink: _ink.quranInk);
        final was = BlockLayout(plain, b, ink: _ink.quranInk);
        final drawn = await pixels(now);
        final before = await pixels(was);
        final stride = now.width.ceil() * 4;
        // Each run of lines with no row between them is the same picture,
        // moved down by whole rows; only the edges of its first and last
        // bands may hold the ink of a line beyond the run.
        final edge = plan.lineHeight / 4;
        var first = 0;
        for (var k = 1; k <= now.lineCount; k++) {
          if (k < now.lineCount &&
              plan.rowExtent(now.block.firstLine + k) == 0) {
            continue;
          }
          final drop = now.lineBand(first).top - was.lineBand(first).top;
          expect(drop, drop.roundToDouble());
          final from = (now.lineBand(first).top + edge).ceil();
          final to = (now.lineBand(k - 1).bottom - edge).floor();
          for (var y = from; y < to; y++) {
            final at = y * stride;
            final old = (y - drop.toInt()) * stride;
            expect(
              drawn.sublist(at, at + stride),
              before.sublist(old, old + stride),
              reason: 'surah ${surah.surah} block $b row of pixels $y',
            );
            compared++;
          }
          first = k;
        }
        now.dispose();
        was.dispose();
      }
    }
    expect(lastLineMoved, isTrue, reason: 'a row inside the last paragraph');
    expect(compared, greaterThan(1000));
  });

  test('a word wider than the line is drawn smaller and stays whole', () {
    final surah = fixture.surahs[overwideSurah]!;
    final plan = SurahLayout.plan(surah, _style(2, 2), 320);
    final first = plan.plannedAyat(plan.segments.first).first;
    expect(first.fontScales[1], lessThan(1));
    final block = BlockLayout(plan, 0, ink: _ink.quranInk);
    final box = block.wordBox(1, 2)!;
    final line = (box.center.dy / plan.lineHeight).floor();
    expect(box.top, closeTo(line * plan.lineHeight, 0.01));
    final (left, right) = block.laidLineExtents[line];
    expect(right, lessThanOrEqualTo(320.5));
    expect(left, greaterThanOrEqualTo(-0.5));
    expect(block.matchesPlan, isTrue);
    block.dispose();
  });

  test('the text size steps run from 80% to 200% over the system scale', () {
    expect(readerTextSteps, [0.8, 0.9, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0]);
    expect(readerTextSteps[defaultReaderTextStep], 1.0);
    expect(nearestReaderTextStep(1.22), readerTextSteps.indexOf(1.15));
    expect(nearestReaderTextStep(3), readerTextSteps.length - 1);
    const scaler = ReaderTextScaler(TextScaler.linear(2), 1.5);
    expect(scaler.scale(25), 75);
    final surah = fixture.surahs[longSurah]!;
    double heightAt(double step) =>
        SurahLayout.plan(surah, _style(1, step), 360).lineHeight;
    // SkParagraph rounds line heights to whole pixels.
    expect(heightAt(2) / heightAt(1), closeTo(2, 0.03));
    expect(
      SurahLayout.plan(surah, _style(1, 2), 360).lines.length,
      greaterThan(SurahLayout.plan(surah, _style(1, 1), 360).lines.length),
    );
  });

  test('the basmala stands alone except in al-Fatiha and al-Tawba', () {
    expect(fixture.surahs[1]!.basmala, isNotNull);
    expect(fixture.surahs[1]!.showsBasmala, isFalse);
    expect(fixture.surahs[9]!.basmala, isNull);
    expect(fixture.surahs[9]!.showsBasmala, isFalse);
    expect(fixture.surahs[longSurah]!.showsBasmala, isTrue);
    final shown = SurahLayout.plan(
      fixture.surahs[longSurah]!,
      _style(1, 1),
      360,
    );
    final none = SurahLayout.plan(fixture.surahs[9]!, _style(1, 1), 360);
    expect(shown.basmalaExtent, greaterThan(0));
    expect(none.basmalaExtent, 0);
  });

  test('the geometry for targets: bands, ayah tops, marks', () {
    final surah = fixture.surahs[longSurah]!;
    final plan = SurahLayout.plan(surah, _style(1, 1), 360);
    for (final block in _laidOut(plan)) {
      expect(block.lineBands, hasLength(block.lineCount));
      expect(block.lineBands.last.bottom, closeTo(block.height, 0.01));
      for (final ayah in block.ayat) {
        expect(plan.blockOfAyah(ayah), block.index);
        final top = block.topOfAyah(ayah)!;
        expect(top, block.ayahBoxes(ayah).first.top);
        for (final mark in surah.ayat[ayah - 1].marks) {
          final boxes = block.markBoxes(ayah, mark.number);
          expect(boxes, isNotEmpty, reason: 'ayah $ayah mark ${mark.number}');
          final word = surah.ayat[ayah - 1].words.lastWhere(
            (w) => w.end <= mark.start,
          );
          final wordBox = block.wordBox(ayah, word.number)!;
          // A mark is drawn on the line of its word, just after it.
          expect(boxes.single.center.dy, closeTo(wordBox.center.dy, 0.01));
          expect(boxes.single.right, lessThanOrEqualTo(wordBox.left + 0.5));
        }
      }
      expect(block.topOfAyah(surah.ayat.length + 1), isNull);
      block.dispose();
    }
  });

  test('positions round-trip from an address to an offset and back', () {
    final surah = fixture.surahs[longSurah]!;
    final plan = SurahLayout.plan(surah, _style(1, 1), 360);
    var previous = -1.0;
    for (var ayah = 1; ayah <= surah.ayat.length; ayah++) {
      final offset = plan.offsetOf(surah.addressOf(ayah));
      expect(offset, greaterThanOrEqualTo(previous));
      previous = offset;
      final at = plan.ayahAt(offset + plan.lineHeight / 2);
      final line = plan.lines[plan.lineOfAyah(ayah)];
      expect(at, surah.addressOf(line.start.ayah + 1));
      expect(at.ayah, lessThanOrEqualTo(ayah));
    }
    expect(plan.ayahAt(0), surah.addressOf(1));
    expect(
      plan.ayahAt(plan.height * 2),
      surah.addressOf(plan.lines.last.start.ayah + 1),
    );
  });

  group('marks that do not fit one row (D-183)', () {
    const width = 300.0;
    const gap = ReaderScreenMetrics.marginRowGap;

    // Every mark at the first ayah, so that all of them belong to one line;
    // each told apart, and given its made-up width, by its hizb.
    MarginMark mark(int hizb) =>
        MarginMark(MarginMarkKind.rub, 1, hizb: hizb, quarter: 2);

    List<List<int>> rowsOf(List<double> widths) {
      final base = fixture.surahs[longSurah]!;
      final text = SurahText(
        riwaya: base.riwaya,
        surah: base.surah,
        ayat: base.ayat,
        basmala: base.basmala,
        pageStarts: base.pageStarts,
        marginMarks: [for (var k = 0; k < widths.length; k++) mark(k + 1)],
      );
      final plan = SurahLayout.plan(
        text,
        _style(1, 1),
        width,
        marginRow: _rowHeight,
        marginMarkWidth: (mark) => widths[mark.hizb! - 1],
      );
      final line = plan.lineOfAyahText(1);
      for (var k = 0; k < plan.lines.length; k++) {
        if (k != line) expect(plan.rowsAbove(k), isEmpty);
      }
      return [
        for (final row in plan.rowsAbove(line))
          [for (final mark in row.marks) mark.hizb!],
      ];
    }

    test('marks exactly as wide as the column stay in one row', () {
      expect(rowsOf([100, width - 100 - gap]), [
        [1, 2],
      ]);
    });

    test('a mark one pixel past the column starts the next row', () {
      expect(rowsOf([100, width - 100 - gap + 1]), [
        [1],
        [2],
      ]);
    });

    test('marks fill three rows in their order', () {
      expect(rowsOf([140, 140, 200, 120, 150]), [
        [1, 2],
        [3],
        [4, 5],
      ]);
    });

    test('a mark wider than the column has a row of its own', () {
      expect(rowsOf([width + 100, 50]), [
        [1],
        [2],
      ]);
      expect(rowsOf([100, width + 100, 100]), [
        [1],
        [2],
        [3],
      ]);
    });
  });
}
