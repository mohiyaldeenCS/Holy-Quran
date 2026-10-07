import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'page_blocks_v2.dart';
import 'render_checks.dart';
import 'spike_surah_text.dart';
import 'surah_paragraph.dart';
import 'synthetic_surah_pack.dart';

// Every text here is Arabic-script nonsense from the spike writer's pack,
// read through LocalPackRepository and PackQuranTextRepository. Timings
// are debug figures on this machine, printed for the record only.

const _widths = [320.0, 360.0, 412.0];
const _scales = [1.0, 2.0];
const _pageMark = Size(30, 20);
const _px = 0.5;

void main() {
  late Directory root;
  late SpikeSurahText long;
  late SpikeSurahText short;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('s1_render');
    final read = await readSyntheticSurahs(root);
    long = read.long;
    short = read.short;
    read.pack.close();
  });
  tearDownAll(() => root.delete(recursive: true));

  for (final scale in _scales) {
    for (final width in _widths) {
      final scaler = TextScaler.linear(scale);
      final where = '${width.toInt()} wide at ${scale}x';

      test('every word round-trips through its box ($where)', () {
        final paragraph = surahParagraph(
          long,
          width: width,
          textScaler: scaler,
          pageMarkSize: _pageMark,
        );
        addTearDown(paragraph.dispose);
        expect(hitRoundTripProblems(paragraph), isEmpty);
        expect(markOrderProblems(paragraph), isEmpty);
      });

      test('nothing overflows the width or its line ($where)', () {
        final paragraph = surahParagraph(
          long,
          width: width,
          textScaler: scaler,
          pageMarkSize: _pageMark,
        );
        addTearDown(paragraph.dispose);
        for (final line in paragraph.lineWidths()) {
          expect(line.natural, lessThanOrEqualTo(width + _px));
          expect(line.laidOut, lessThanOrEqualTo(width + _px));
        }
        final bands = paragraph.lineBands;
        void expectInside(Rect rect, String what) {
          expect(rect.left, greaterThanOrEqualTo(-_px), reason: what);
          expect(rect.right, lessThanOrEqualTo(width + _px), reason: what);
          expect(
            bands.where(
              (b) => b.top - _px <= rect.top && rect.bottom <= b.bottom + _px,
            ),
            hasLength(1),
            reason: '$what lies in one band',
          );
        }

        final content = paragraph.content;
        for (var i = 0; i < content.length; i++) {
          expectInside(paragraph.markerRect(i), 'marker ${content.ayahAt(i)}');
        }
        for (final i in content.pageMarkIndices) {
          expectInside(paragraph.pageMarkRect(i), 'page mark before $i');
        }
      });

      test('topOf rises with the ayah number ($where)', () {
        final paragraph = surahParagraph(
          long,
          width: width,
          textScaler: scaler,
        );
        addTearDown(paragraph.dispose);
        final tops = [
          for (var i = 0; i < long.ayat.length; i++)
            paragraph.topOf(paragraph.content.ayahAt(i))!,
        ];
        for (var i = 1; i < tops.length; i++) {
          expect(tops[i], greaterThanOrEqualTo(tops[i - 1]));
        }
        for (final (i, top) in tops.indexed) {
          final ayah = paragraph.content.ayahAt(i);
          final first = QuranAddress(ayah.riwaya, ayah.surah, ayah.ayah, 1);
          expect(
            paragraph.boxesOf(first).first.top,
            inInclusiveRange(top - 0.01, top + _px + 0.01),
            reason: 'the margin mark of $ayah sits on its first word line',
          );
        }
      });

      test('V2 blocks break every line as V1 does ($where)', () {
        for (final mark in [_pageMark, null]) {
          final v1 = surahParagraph(
            long,
            width: width,
            textScaler: scaler,
            pageMarkSize: mark,
          );
          final planner = SurahFlowPlanner(
            surah: long,
            width: width,
            textScaler: scaler,
            pageMarkSize: mark,
          );
          expect(flowLineStarts(planner), v1.lineStartPositions);
          expect(
            planner.all.length,
            greaterThan(long.pageStarts.length ~/ 2),
            reason: 'about one block per page',
          );
          v1.dispose();
        }
      });
    }
  }

  test('page marks sit inside the line, with text on both sides', () {
    for (final scale in _scales) {
      final paragraph = surahParagraph(
        long,
        width: 360,
        textScaler: TextScaler.linear(scale),
        pageMarkSize: _pageMark,
      );
      addTearDown(paragraph.dispose);
      final bands = paragraph.lineBands;
      final content = paragraph.content;
      var inside = 0;
      for (final i in content.pageMarkIndices) {
        final mark = paragraph.pageMarkRect(i);
        final line = _bandOf(bands, mark);
        expect(paragraph.lineOfAyah(i), line);
        final before = paragraph.boxesOf(content.ayahAt(i - 1)).last;
        final ayah = content.ayahAt(i);
        final after = paragraph
            .boxesOf(QuranAddress(ayah.riwaya, ayah.surah, ayah.ayah, 1))
            .first;
        if (_bandOf(bands, before) == line && _bandOf(bands, after) == line) {
          final why = 'mark $i: before $before mark $mark after $after';
          expect(
            before.left,
            greaterThanOrEqualTo(mark.right - _px),
            reason: why,
          );
          expect(after.right, lessThanOrEqualTo(mark.left + _px), reason: why);
          inside++;
        }
      }
      // ignore: avoid_print
      print(
        'page marks with text on both sides in their line at ${scale}x: '
        '$inside of ${content.pageMarkIndices.length}',
      );
      expect(inside, greaterThan(0));
    }
  });

  for (final cut in BandCut.values) {
    test('centring moves only the last line, and centres it (${cut.name})', () {
      for (final surah in [long, short]) {
        for (final scale in _scales) {
          final scaler = TextScaler.linear(scale);
          final plain = surahParagraph(
            surah,
            width: 360,
            textScaler: scaler,
            centreLastLine: false,
          );
          final centred = surahParagraph(
            surah,
            width: 360,
            textScaler: scaler,
            cut: cut,
          );
          addTearDown(plain.dispose);
          addTearDown(centred.dispose);
          expect(centred.recoloured, cut == BandCut.recolour);
          final bands = centred.lineBands;
          final last = bands.length - 1;
          final shift = centred.lastLineShift;
          expect(shift, lessThan(0), reason: 'right to left: it moves left');
          final onLast = <Rect>[];
          final content = centred.content;
          for (var i = 0; i < content.length; i++) {
            final ayah = content.ayahAt(i);
            for (final address in [
              ayah,
              for (final w in content.words[i])
                QuranAddress(ayah.riwaya, ayah.surah, ayah.ayah, w.number),
            ]) {
              final a = plain.boxesOf(address);
              final b = centred.boxesOf(address);
              expect(b, hasLength(a.length));
              for (var k = 0; k < a.length; k++) {
                final moved = _bandOf(bands, b[k]) == last;
                final expected = moved ? a[k].shift(Offset(shift, 0)) : a[k];
                expect(b[k].left, moreOrLessEquals(expected.left));
                expect(b[k].right, moreOrLessEquals(expected.right));
                if (moved && address.isWord) onLast.add(b[k]);
              }
            }
            final marker = centred.markerRect(i);
            if (_bandOf(bands, marker) == last) onLast.add(marker);
          }
          final line = onLast.reduce((a, b) => a.expandToInclude(b));
          expect(line.center.dx, moreOrLessEquals(180, epsilon: _px));
        }
      }
    });
  }

  test('a centred last line is the same ink, moved, and the lines above '
      'are untouched', () async {
    final plain = surahParagraph(
      short,
      width: 360,
      textScaler: TextScaler.noScaling,
      centreLastLine: false,
    );
    addTearDown(plain.dispose);
    final a = await _render(plain);
    for (final cut in BandCut.values) {
      final centred = surahParagraph(
        short,
        width: 360,
        textScaler: TextScaler.noScaling,
        cut: cut,
      );
      addTearDown(centred.dispose);
      final b = await _render(centred);
      final edge = centred.lineBands.last.top.floor();
      final untouched = switch (cut) {
        BandCut.clip => edge,
        BandCut.recolour => edge - _overhang,
      };
      for (var y = 0; y < untouched; y++) {
        expect(a.row(y), b.row(y), reason: '${cut.name}: row $y');
      }
      final before = a.inkColumns(edge + _overhang, a.height);
      final after = b.inkColumns(edge + _overhang, b.height);
      final shift = centred.lastLineShift;
      expect(after.$1, closeTo(before.$1 + shift, 1.5), reason: cut.name);
      expect(after.$2, closeTo(before.$2 + shift, 1.5), reason: cut.name);
    }
  });

  test('a centred last line that starts at a word shaped with the word '
      'before it keeps that shaping, even when it is nearly full', () async {
    // Amiri Quran shapes some words narrower after another word, across the
    // space (a word-initial kaf by 0.24 em). A last line laid out on its own
    // lost that context, grew, and wrapped: surah 24 of T6's full synthetic
    // pack at 412 wide, 2.0x. Find a block here whose last line starts with
    // such a word and is too full to fit without the context.
    const scaler = TextScaler.noScaling;
    double widthOf(String value) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: quranPageStyle),
        textDirection: TextDirection.rtl,
        textScaler: scaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    SurahParagraph? plain;
    for (var i = 0; i < long.ayat.length && plain == null; i++) {
      final text = long.ayat[i].verbatim;
      final words = long.words[i];
      final ayah = QuranAddress(long.firstAyah.riwaya, 1, i + 1);
      for (var k = 1; k < words.length && plain == null; k++) {
        final word = text.substring(words[k].start, words[k].end);
        final before = text.substring(words[k - 1].start, words[k].start);
        final alone = widthOf(word);
        if (widthOf(before + word) - widthOf(before) - alone > -3) continue;
        for (var j = k - 1; j >= 0 && j >= k - 3 && plain == null; j--) {
          final surah = SpikeSurahText(
            firstAyah: ayah,
            ayat: [long.ayat[i]],
            words: [words],
            basmala: null,
            pageStarts: const {},
          );
          final content = SurahBlockContent(
            firstAyah: ayah,
            ayat: surah.ayat,
            words: surah.words,
            startOffset: words[j].start,
          );
          for (var width = 120.0; width <= 700 && plain == null; width += .25) {
            final candidate = SurahParagraph(
              content,
              style: quranPageStyle,
              textScaler: scaler,
              markerSizes: [ayahMarkerSize(scaler, AppSizes.ayahMarker)],
            )..layout(width);
            final inContext = candidate
                .boxesOf(QuranAddress(ayah.riwaya, 1, i + 1, words[k].number))
                .single
                .width;
            final lone =
                candidate.lineWidths().last.laidOut - inContext + alone;
            if (candidate.lineCount > 1 &&
                candidate.lineStartPositions.last ==
                    (ayah: i + 1, offset: words[k].start) &&
                lone > width) {
              plain = candidate;
            } else {
              candidate.dispose();
            }
          }
        }
      }
    }
    expect(plain, isNotNull, reason: 'the pack holds such a block');
    addTearDown(plain!.dispose);
    final centred = SurahParagraph(
      plain.content,
      style: quranPageStyle,
      textScaler: scaler,
      markerSizes: [ayahMarkerSize(scaler, AppSizes.ayahMarker)],
      centreLastLine: true,
    )..layout(plain.width);
    addTearDown(centred.dispose);
    expect(centred.recoloured, isTrue);
    expect(centred.lineStartPositions, plain.lineStartPositions);
    final a = await _render(plain);
    final b = await _render(centred);
    // The band's middle rows: the line above reaches into its top rows.
    final band = centred.lineBands.last;
    final from = (band.top + band.height / 3).floor();
    final to = (band.bottom - band.height / 6).floor();
    final before = a.inkColumns(from, to);
    final after = b.inkColumns(from, to);
    final shift = centred.lastLineShift;
    expect(after.$1, closeTo(before.$1 + shift, 1.5));
    expect(after.$2, closeTo(before.$2 + shift, 1.5));
    expect(after.$2 - after.$1, closeTo(before.$2 - before.$1, 1));
  });

  test('ink on the rows at band edges is found', () async {
    final squeezed = surahParagraph(
      short,
      width: 360,
      textScaler: TextScaler.noScaling,
      centreLastLine: false,
      style: quranPageStyle.copyWith(height: 1),
    );
    addTearDown(squeezed.dispose);
    final forced = await bandEdgeInk(squeezed);
    expect(forced.where((e) => e.above > 0 && e.below > 0), isNotEmpty);

    for (final scale in _scales) {
      final paragraph = surahParagraph(
        long,
        width: 360,
        textScaler: TextScaler.linear(scale),
        centreLastLine: false,
      );
      addTearDown(paragraph.dispose);
      final edges = await bandEdgeInk(paragraph, pixelRatio: 2);
      expect(edges, hasLength(paragraph.lineCount - 1));
      final touched = edges.where((e) => e.above > 0 || e.below > 0).length;
      final crossed = edges.where((e) => e.above > 0 && e.below > 0).length;
      // ignore: avoid_print
      print(
        'band-edge ink at ${scale}x, 25 / 2.3, 2 px per px: of '
        '${edges.length} edges $touched have ink on a row beside the edge, '
        '$crossed on both rows',
      );
    }
  });

  test('a block starts at a stored word offset only', () {
    expect(
      () => SurahBlockContent(
        firstAyah: long.firstAyah,
        ayat: [long.ayat.first],
        words: [long.words.first],
        startOffset: long.words.first.first.end,
      ),
      throwsArgumentError,
    );
    expect(
      SurahBlockContent(
        firstAyah: long.firstAyah,
        ayat: [long.ayat.first],
        words: [long.words.first],
        startOffset: long.words.first[1].start,
      ).startOffset,
      long.words.first[1].start,
    );
  });

  test('layout time, stretch and line-start fingerprints (informative)', () {
    for (final scale in _scales) {
      final scaler = TextScaler.linear(scale);
      final clock = Stopwatch()..start();
      final v1 = surahParagraph(
        long,
        width: 360,
        textScaler: scaler,
        pageMarkSize: _pageMark,
      );
      final v1Time = clock.elapsedMicroseconds;
      clock.reset();
      final planner = SurahFlowPlanner(
        surah: long,
        width: 360,
        textScaler: scaler,
        pageMarkSize: _pageMark,
      );
      final blocks = planner.all;
      final planTime = clock.elapsedMicroseconds;
      final perBlock = <int>[];
      for (final block in blocks) {
        clock.reset();
        planner.paragraphFor(block).dispose();
        perBlock.add(clock.elapsedMicroseconds);
      }
      perBlock.sort();
      final stretch = lineStretch(v1);
      final maxStretch = stretch
          .map((s) => s.words > 1 ? s.stretch / (s.words - 1) : s.stretch)
          .reduce((a, b) => a > b ? a : b);
      // ignore: avoid_print
      print(
        'surah of ${long.ayat.length} ayat, '
        '${long.words.fold(0, (n, w) => n + w.length)} words at 360, '
        '${scale}x: V1 layout ${v1Time ~/ 1000} ms, ${v1.lineCount} lines; '
        'V2 plan ${planTime ~/ 1000} ms for ${blocks.length} blocks, block '
        'layout median ${perBlock[perBlock.length ~/ 2] ~/ 1000} ms, max '
        '${perBlock.last ~/ 1000} ms; widest stretch per gap '
        '${maxStretch.toStringAsFixed(1)} px; fingerprint '
        '${lineStartFingerprint(v1.lineStartPositions).substring(0, 16)}',
      );
      v1.dispose();
    }
  });
}

int _bandOf(List<Rect> bands, Rect rect) =>
    bands.indexWhere((band) => band.contains(rect.center));

// Rows above a band edge that ink of the line below may reach; the font's
// ascent passes the line's by about 2 px at 25 px.
const int _overhang = 12;

const int _margin = 16;

/// Renders [paragraph] with [_margin] on each side, as glyphs may overhang
/// the paragraph's edges.
Future<_Image> _render(SurahParagraph paragraph) async {
  final width = paragraph.width.ceil() + 2 * _margin;
  final height = paragraph.height.ceil();
  final recorder = ui.PictureRecorder();
  paragraph.paint(Canvas(recorder), Offset(_margin.toDouble(), 0));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = (await image.toByteData())!;
  image.dispose();
  picture.dispose();
  return _Image(bytes, width, height);
}

final class _Image {
  const _Image(this.bytes, this.width, this.height);

  final ByteData bytes;
  final int width;
  final int height;

  List<int> row(int y) =>
      bytes.buffer.asUint8List(bytes.offsetInBytes + y * width * 4, width * 4);

  /// The leftmost and rightmost columns with ink in rows [from] to [to].
  (int, int) inkColumns(int from, int to) {
    var left = width;
    var right = -1;
    for (var y = from; y < to; y++) {
      for (var x = 0; x < width; x++) {
        if (bytes.getUint8((y * width + x) * 4 + 3) > 0) {
          if (x < left) left = x;
          if (x > right) right = x;
        }
      }
    }
    return (left, right);
  }
}
