import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'page_blocks_v2.dart';
import 'spike_surah_text.dart';
import 'surah_paragraph.dart';

/// The surah-mode style of `QuranText`, in the paper theme's `quran-ink`.
final TextStyle quranPageStyle = AppTextStyles.quranPage.copyWith(
  color: AppColors.paper.quranInk,
);

// Checks on laid-out surah text, shared by the synthetic tests and the
// real-text measurement (T6). Results hold addresses and numbers only,
// never text.

/// [surah] laid out as V1 lays it out, as one block, with the sizes
/// `AyahMarker` takes under [textScaler] and every page mark held to
/// [pageMarkSize] (none when null).
SurahParagraph surahParagraph(
  SpikeSurahText surah, {
  required double width,
  required TextScaler textScaler,
  Size? pageMarkSize,
  bool centreLastLine = true,
  TextStyle? style,
  BandCut cut = BandCut.recolour,
}) {
  final content = SurahBlockContent(
    firstAyah: surah.firstAyah,
    ayat: surah.ayat,
    words: surah.words,
    basmala: surah.basmala,
    pageMarks: pageMarkSize == null ? const {} : surah.pageStarts.keys.toSet(),
  );
  return SurahParagraph(
    content,
    style: style ?? quranPageStyle,
    textScaler: textScaler,
    markerSizes: List.filled(
      content.length,
      ayahMarkerSize(textScaler, AppSizes.ayahMarker),
    ),
    pageMarkSizes: List.filled(
      content.pageMarks.length,
      pageMarkSize ?? Size.zero,
    ),
    centreLastLine: centreLastLine,
    cut: cut,
  )..layout(width);
}

/// The shown line starts of every V2 block, in order.
List<LineStart> flowLineStarts(SurahFlowPlanner planner) {
  final starts = <LineStart>[];
  for (final block in planner.all) {
    final paragraph = planner.paragraphFor(block);
    starts.addAll(paragraph.lineStartPositions);
    paragraph.dispose();
  }
  return starts;
}

/// A digest of [starts], to compare line breaking across runs, devices and
/// layouts without keeping the starts themselves.
String lineStartFingerprint(List<LineStart> starts) => sha256
    .convert(
      utf8.encode([for (final s in starts) '${s.ayah}:${s.offset}'].join(',')),
    )
    .toString();

/// Every word shown in [paragraph]: its boxes are non-empty, it sits on one
/// line, its box lies inside that line's band and across the block's
/// width, and the centre of its box hits the same word.
List<String> hitRoundTripProblems(SurahParagraph paragraph) {
  const slack = 0.5;
  final content = paragraph.content;
  final bands = paragraph.lineBands;
  final problems = <String>[];
  for (var i = 0; i < content.length; i++) {
    final ayah = content.ayahAt(i);
    for (final word in content.words[i]) {
      if (word.start < content.baseOf(i)) continue;
      final address = QuranAddress(
        ayah.riwaya,
        ayah.surah,
        ayah.ayah,
        word.number,
      );
      final boxes = paragraph.boxesOf(address);
      if (boxes.isEmpty) {
        if (paragraph.visibleLineCount == paragraph.lineCount) {
          problems.add('$address: no box');
        }
        continue;
      }
      if (boxes.length > 1) problems.add('$address: on ${boxes.length} lines');
      final box = boxes.first;
      if (box.width <= 0 || box.height <= 0) problems.add('$address: empty');
      final band = bands.where((b) => b.contains(box.center));
      if (band.length != 1 ||
          box.top < band.single.top - slack ||
          box.bottom > band.single.bottom + slack) {
        problems.add('$address: outside its line band');
      }
      if (box.left < -slack || box.right > paragraph.width + slack) {
        problems.add('$address: outside the width');
      }
      final hit = paragraph.hit(box.center);
      if (hit != address) problems.add('$address: centre hits $hit');
    }
  }
  return problems;
}

/// Whether every marker and page mark is drawn in reading order: right to
/// left on its line, after what comes before it and before what follows.
/// This catches SkParagraph's reordering of placeholders on right-to-left
/// lines (`SurahParagraph`).
List<String> markOrderProblems(SurahParagraph paragraph) {
  const slack = 0.5;
  final content = paragraph.content;
  final bands = paragraph.lineBands;
  int lineOf(Rect rect) => bands.indexWhere((b) => b.contains(rect.center));
  QuranAddress word(int i, int number) {
    final ayah = content.ayahAt(i);
    return QuranAddress(ayah.riwaya, ayah.surah, ayah.ayah, number);
  }

  // Everything drawn, in reading order, by line.
  final items = <(String, Rect)>[];
  for (var i = 0; i < content.length; i++) {
    if (content.pageMarks.contains(content.ayahAt(i))) {
      items.add((
        'page mark before ${content.ayahAt(i)}',
        paragraph.pageMarkRect(i),
      ));
    }
    for (final span in content.words[i]) {
      if (span.start < content.baseOf(i)) continue;
      final boxes = paragraph.boxesOf(word(i, span.number));
      for (final box in boxes) {
        items.add(('${word(i, span.number)}', box));
      }
    }
    items.add(('marker ${content.ayahAt(i)}', paragraph.markerRect(i)));
  }
  final problems = <String>[];
  for (var k = 1; k < items.length; k++) {
    final (before, a) = items[k - 1];
    final (after, b) = items[k];
    final line = lineOf(b);
    if (line < 0) continue;
    if (line == lineOf(a) && b.right > a.left + slack) {
      problems.add('$after is not left of $before');
    }
  }
  return problems;
}

/// Where colouring one word changes the layout: [content] laid out as it
/// is and with [word] in [colour], which cuts its ayah at every stored word
/// offset (`WQ-01`, tajweed). Compares height, lines, line widths, marker
/// places and every word's boxes.
List<String> slicingProblems(
  SurahBlockContent content, {
  required QuranAddress word,
  required Color colour,
  required double width,
  required TextScaler textScaler,
}) {
  const tolerance = 0.01;
  SurahParagraph laidOut(Map<QuranAddress, Color> colours) => SurahParagraph(
    SurahBlockContent(
      firstAyah: content.firstAyah,
      ayat: content.ayat,
      words: content.words,
      basmala: content.basmala,
      startOffset: content.startOffset,
      pageMarks: content.pageMarks,
      wordColours: colours,
    ),
    style: quranPageStyle,
    textScaler: textScaler,
    markerSizes: List.filled(
      content.length,
      ayahMarkerSize(textScaler, AppSizes.ayahMarker),
    ),
    pageMarkSizes: List.filled(content.pageMarks.length, Size.zero),
  )..layout(width);

  bool near(Rect a, Rect b) =>
      (a.left - b.left).abs() < tolerance &&
      (a.top - b.top).abs() < tolerance &&
      (a.right - b.right).abs() < tolerance &&
      (a.bottom - b.bottom).abs() < tolerance;

  final whole = laidOut(const {});
  final sliced = laidOut({word: colour});
  final problems = <String>[
    if ((whole.height - sliced.height).abs() > tolerance) 'height differs',
    if (!_sameInts(whole.lineStarts, sliced.lineStarts)) 'lines differ',
  ];
  final a = whole.lineWidths();
  final b = sliced.lineWidths();
  for (var k = 0; k < a.length && k < b.length; k++) {
    if ((a[k].laidOut - b[k].laidOut).abs() > tolerance ||
        (a[k].natural - b[k].natural).abs() > tolerance) {
      problems.add('line $k: width differs');
    }
  }
  for (var i = 0; i < content.length; i++) {
    if (!near(whole.markerRect(i), sliced.markerRect(i))) {
      problems.add('${content.ayahAt(i)}: marker moved');
    }
    final ayah = content.ayahAt(i);
    for (final span in content.words[i]) {
      final address = QuranAddress(
        ayah.riwaya,
        ayah.surah,
        ayah.ayah,
        span.number,
      );
      final x = whole.boxesOf(address);
      final y = sliced.boxesOf(address);
      var same = x.length == y.length;
      for (var k = 0; same && k < x.length; k++) {
        same = near(x[k], y[k]);
      }
      if (!same) {
        problems.add('$address: boxes differ');
      }
    }
  }
  whole.dispose();
  sliced.dispose();
  return problems;
}

bool _sameInts(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The stretch justification adds to each shown line but the last, and the
/// number of words that start on it.
List<({int line, double stretch, int words})> lineStretch(
  SurahParagraph paragraph,
) {
  final widths = paragraph.lineWidths();
  final starts = paragraph.lineStartPositions;
  final content = paragraph.content;
  final counts = List.filled(starts.length, 0);
  var line = 0;
  for (var i = 0; i < content.length; i++) {
    final ayah = content.ayahAt(i).ayah;
    for (final word in content.words[i]) {
      if (word.start < content.baseOf(i) ||
          !_notAfter(starts.first, ayah, word.start)) {
        continue;
      }
      while (line + 1 < starts.length &&
          _notAfter(starts[line + 1], ayah, word.start)) {
        line++;
      }
      counts[line]++;
    }
  }
  return [
    for (var k = 0; k < widths.length - 1; k++)
      (
        line: k,
        stretch: widths[k].laidOut - widths[k].natural,
        words: counts[k],
      ),
  ];
}

bool _notAfter(LineStart start, int ayah, int offset) =>
    start.ayah < ayah || (start.ayah == ayah && start.offset <= offset);

/// Ink on the two pixel rows either side of each edge between line bands,
/// with the text drawn as laid out at [pixelRatio]. It cannot tell which
/// line the ink belongs to; [bandInk] can, and supersedes it. [paragraph]
/// must show and draw every line in place: laid out without centring or
/// [maxLines].
Future<List<({int edge, int above, int below})>> bandEdgeInk(
  SurahParagraph paragraph, {
  double pixelRatio = 1,
}) async {
  if (paragraph.recoloured || paragraph.lastLineShift != 0) {
    throw ArgumentError('the paragraph does not draw every line in place');
  }
  final bands = paragraph.lineBands;
  final top = paragraph.bodyTop;
  final width = (paragraph.width * pixelRatio).ceil();
  final rows = [
    for (var k = 1; k < bands.length; k++)
      ((bands[k].top - top) * pixelRatio).floor(),
  ];
  final edges = <({int edge, int above, int below})>[];
  var next = 0;
  while (next < rows.length) {
    final first = rows[next] - 1;
    final ink = await _inkPerRow(
      paragraph,
      width: width,
      firstRow: first,
      rowCount: _tileRows,
      pixelRatio: pixelRatio,
    );
    while (next < rows.length && rows[next] < first + _tileRows) {
      final row = rows[next] - first;
      edges.add((edge: next + 1, above: ink[row - 1], below: ink[row]));
      next++;
    }
  }
  return edges;
}

// Rows rendered at a time by bandEdgeInk, so that a long surah never needs
// one image of its whole height.
const int _tileRows = 2048;

// The alpha byte of an RGBA pixel read as one little-endian word.
const int _alpha = 0xFF000000;

/// The number of pixels with any ink on each of [rowCount] rows from
/// [firstRow], the body drawn at [pixelRatio].
Future<List<int>> _inkPerRow(
  SurahParagraph paragraph, {
  required int width,
  required int firstRow,
  required int rowCount,
  required double pixelRatio,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..translate(0, -firstRow.toDouble())
    ..clipRect(
      Rect.fromLTWH(
        0,
        firstRow.toDouble(),
        width.toDouble(),
        rowCount.toDouble(),
      ),
    )
    ..scale(pixelRatio);
  paragraph.paintUnclipped(canvas, Offset.zero);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, rowCount);
  final bytes = (await image.toByteData())!;
  image.dispose();
  picture.dispose();
  final ink = List.filled(rowCount, 0);
  for (var y = 0; y < rowCount; y++) {
    for (var x = 0; x < width; x++) {
      if (bytes.getUint8((y * width + x) * 4 + 3) > 0) ink[y]++;
    }
  }
  return ink;
}

/// One line's ink outside its band: pixels and the farthest reach, in
/// logical px, above and below.
typedef LineInk = ({
  int line,
  int above,
  int below,
  double reachUp,
  double reachDown,
});

/// Where ink leaves its line's band, by line and by edge. [edges] holds,
/// for the edge above line `edge`, the pixels of the line above that cross
/// it downward ([LineInk.below] of that line), of the line below that cross
/// it upward, and the farther reach of the two.
typedef BandInk = ({
  int lines,
  int linesLeaving,
  double maxReach,
  int aboveFirst,
  int belowLast,
  List<({int edge, int down, int up, double reach})> edges,
  List<LineInk> perLine,
});

/// Which line's ink leaves its band, and how far: the clipping of
/// [BandCut.clip] is safe only where no line's ink does.
///
/// The text is drawn three times, each time with only the lines k for
/// which k mod 3 is one value visible and the others transparent (colour
/// does not change layout). The pixels with ink in the bands next to line
/// k are then line k's, as long as no ink reaches past a whole band, which
/// [BandInk.maxReach] shows. Two passes would not do: in the band between
/// lines k and k + 2 their ink could not be told apart. [paragraph] must
/// show every line: no lead-in or [SurahParagraph.maxLines].
Future<BandInk> bandInk(
  SurahParagraph paragraph, {
  double pixelRatio = 1,
}) async {
  if (paragraph.firstShownLine != 0 ||
      paragraph.visibleLineCount != paragraph.lineCount) {
    throw ArgumentError('the paragraph does not show every line');
  }
  final bands = [
    for (final band in paragraph.lineBands)
      band.shift(Offset(0, -paragraph.bodyTop)),
  ];
  final lines = bands.length;
  if (lines == 0) {
    return (
      lines: 0,
      linesLeaving: 0,
      maxReach: 0.0,
      aboveFirst: 0,
      belowLast: 0,
      edges: const <({int edge, int down, int up, double reach})>[],
      perLine: const <LineInk>[],
    );
  }
  final tallest = bands.map((b) => b.height).reduce(math.max);
  final margin = (tallest * pixelRatio).ceil();
  final width = (paragraph.width * pixelRatio).ceil() + 2 * margin;
  final rows = (bands.last.bottom * pixelRatio).ceil() + 2 * margin;
  final perLine = List<LineInk?>.filled(lines, null);
  for (var pass = 0; pass < 3; pass++) {
    final drawn = paragraph.paragraphShowing((k) => k % 3 == pass);
    final ink = Int32List(rows);
    for (var first = 0; first < rows; first += _tileRows) {
      final count = math.min(_tileRows, rows - first);
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..translate(margin.toDouble(), (margin - first).toDouble())
        ..scale(pixelRatio)
        ..drawParagraph(drawn, Offset.zero);
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, count);
      final pixels = (await image.toByteData())!.buffer.asUint32List();
      image.dispose();
      picture.dispose();
      for (var y = 0; y < count; y++) {
        var n = 0;
        for (var i = y * width, end = i + width; i < end; i++) {
          if (pixels[i] & _alpha != 0) n++;
        }
        ink[first + y] = n;
      }
    }
    drawn.dispose();
    for (var k = pass; k < lines; k += 3) {
      // Rows from the band above to the band below, in pixels from the
      // body's top; the first and last lines reach into the margins.
      final top = bands[k].top * pixelRatio;
      final bottom = bands[k].bottom * pixelRatio;
      final from = k > 0 ? bands[k - 1].top * pixelRatio : -margin.toDouble();
      final to = k + 1 < lines
          ? bands[k + 1].bottom * pixelRatio
          : (rows - margin).toDouble();
      var above = 0;
      var below = 0;
      var reachUp = 0.0;
      var reachDown = 0.0;
      for (var y = from.floor(); y < to.ceil(); y++) {
        final n = ink[y + margin];
        if (n == 0) continue;
        if (y + 1 <= top) {
          above += n;
          reachUp = math.max(reachUp, (top - y) / pixelRatio);
        } else if (y >= bottom) {
          below += n;
          reachDown = math.max(reachDown, (y + 1 - bottom) / pixelRatio);
        }
      }
      perLine[k] = (
        line: k,
        above: above,
        below: below,
        reachUp: reachUp,
        reachDown: reachDown,
      );
    }
  }
  final all = [for (final line in perLine) line!];
  return (
    lines: lines,
    linesLeaving: all.where((l) => l.above > 0 || l.below > 0).length,
    maxReach: all.map((l) => math.max(l.reachUp, l.reachDown)).reduce(math.max),
    aboveFirst: all.first.above,
    belowLast: all.last.below,
    edges: [
      for (var k = 1; k < lines; k++)
        (
          edge: k,
          down: all[k - 1].below,
          up: all[k].above,
          reach: math.max(all[k - 1].reachDown, all[k].reachUp),
        ),
    ],
    perLine: all,
  );
}

/// [ink] as JSON: numbers, lists and maps only.
Map<String, Object> bandInkJson(BandInk ink) => {
  'lines': ink.lines,
  'linesLeaving': ink.linesLeaving,
  'maxReach': ink.maxReach,
  'aboveFirst': ink.aboveFirst,
  'belowLast': ink.belowLast,
  'edges': [
    for (final e in ink.edges)
      {'edge': e.edge, 'down': e.down, 'up': e.up, 'reach': e.reach},
  ],
};
