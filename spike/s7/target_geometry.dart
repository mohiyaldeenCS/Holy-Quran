import 'dart:ui';

import 'package:holyquran/domain/models/quran_address.dart';

import '../s1/render/surah_paragraph.dart';

/// Where the tap targets of one text block are drawn, in block coordinates
/// and on shown lines only (D-095): the bands of the lines, each word's
/// rects (one per line), each mark's box (the space before it and the
/// mark, `SurahParagraph.markBoxOf`) and each ayah marker. Numbers and
/// addresses only, never text.
final class TargetGeometry {
  TargetGeometry({
    required List<Rect> lineBands,
    Map<QuranAddress, List<Rect>> words = const {},
    Map<(QuranAddress, int), Rect> marks = const {},
    Map<QuranAddress, Rect> markers = const {},
    List<(QuranAddress, int)> marksWithoutBox = const [],
  }) : lineBands = List.unmodifiable(lineBands),
       words = Map.unmodifiable({
         for (final MapEntry(:key, :value) in words.entries)
           key: List<Rect>.unmodifiable(value),
       }),
       marks = Map.unmodifiable(marks),
       markers = Map.unmodifiable(markers),
       marksWithoutBox = List.unmodifiable(marksWithoutBox);

  /// The targets of [paragraph] on its shown lines; with [within], only on
  /// the lines whose band overlaps it, and only the ayat on those lines are
  /// visited, so that a tap never costs a pass over the whole surah.
  factory TargetGeometry.of(SurahParagraph paragraph, {Rect? within}) {
    final lines = paragraph.visibleLineCount;
    var first = 0;
    var last = lines - 1;
    if (within != null) {
      // Bands tile the body top to bottom: find the first one past the top
      // of within, then walk down while they overlap it.
      var high = lines;
      while (first < high) {
        final middle = (first + high) ~/ 2;
        if (paragraph.lineBand(middle).bottom <= within.top) {
          first = middle + 1;
        } else {
          high = middle;
        }
      }
      last = first - 1;
      while (last + 1 < lines &&
          paragraph.lineBand(last + 1).overlaps(within)) {
        last++;
      }
    }
    if (first > last) return TargetGeometry(lineBands: const []);
    final bands = [for (var k = first; k <= last; k++) paragraph.lineBand(k)];
    bool onKept(Rect rect) =>
        bands.first.top <= rect.center.dy && rect.center.dy < bands.last.bottom;

    final content = paragraph.content;
    final firstAyah = content.firstAyah.ayah;
    final from = paragraph.lineStartPosition(first).ayah - firstAyah;
    final to = last + 1 < lines
        ? paragraph.lineStartPosition(last + 1).ayah - firstAyah
        : content.length - 1;

    final words = <QuranAddress, List<Rect>>{};
    final marks = <(QuranAddress, int), Rect>{};
    final markers = <QuranAddress, Rect>{};
    final withoutBox = <(QuranAddress, int)>[];
    for (var i = from; i <= to; i++) {
      final ayah = content.ayahAt(i);
      for (final word in content.words[i]) {
        final address = QuranAddress(
          ayah.riwaya,
          ayah.surah,
          ayah.ayah,
          word.number,
        );
        final rects = paragraph.boxesOf(address).where(onKept).toList();
        if (rects.isNotEmpty) words[address] = rects;
      }
      for (final mark in content.marks[i]) {
        final placed = paragraph.markBoxOf(ayah, mark.number);
        if (placed == null || placed.line < first || placed.line > last) {
          continue;
        }
        if (placed.box case final box?) {
          marks[(ayah, mark.number)] = box;
        } else {
          withoutBox.add((ayah, mark.number));
        }
      }
      final marker = paragraph.markerRect(i);
      if (paragraph.isVisible(marker) && onKept(marker)) markers[ayah] = marker;
    }
    return TargetGeometry(
      lineBands: bands,
      words: words,
      marks: marks,
      markers: markers,
      marksWithoutBox: withoutBox,
    );
  }

  final List<Rect> lineBands;
  final Map<QuranAddress, List<Rect>> words;

  /// Mark boxes by ayah and mark number, for the marks that have one.
  final Map<(QuranAddress, int), Rect> marks;
  final Map<QuranAddress, Rect> markers;

  /// Marks on the kept lines for which the engine gave no box of positive
  /// width. On the synthetic pack: most marks that start a line, a mark
  /// that opens its ayah (after the marker, with no space before it), and
  /// now and then one on the line above a line-start mark, whose boxes the
  /// engine puts past the left edge. They cannot be tapped.
  final List<(QuranAddress, int)> marksWithoutBox;

  /// The index of the band holding [y], or null off every band.
  int? bandAt(double y) {
    for (final (k, band) in lineBands.indexed) {
      if (band.top <= y && y < band.bottom) return k;
    }
    return null;
  }
}
