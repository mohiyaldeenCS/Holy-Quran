import 'dart:ui';

import 'package:holyquran/domain/models/quran_address.dart';

import 'block_layout.dart';

/// Where the tap targets of one text block are drawn, in block coordinates
/// (D-095): the bands of the lines, each word's rect, each mark's box and
/// each ayah marker. Numbers and addresses only, never text.
final class TargetGeometry {
  TargetGeometry({
    required List<Rect> lineBands,
    Map<QuranAddress, Rect> words = const {},
    Map<(QuranAddress, int), Rect> marks = const {},
    Map<QuranAddress, Rect> markers = const {},
  }) : lineBands = List.unmodifiable(lineBands),
       words = Map.unmodifiable(words),
       marks = Map.unmodifiable(marks),
       markers = Map.unmodifiable(markers);

  /// The targets of [layout]; with [within], only those on the lines whose
  /// band overlaps it, and only the ayat on those lines are visited, so that
  /// a tap never costs a pass over the whole block.
  factory TargetGeometry.of(BlockLayout layout, {Rect? within}) {
    final plan = layout.plan;
    final firstLine = layout.block.firstLine;
    final all = layout.lineBands;
    final kept = [
      for (final (line, band) in all.indexed)
        if (within == null ||
            (band.top < within.bottom && band.bottom > within.top))
          line,
    ];
    if (kept.isEmpty) return TargetGeometry(lineBands: const []);
    final bands = [for (final line in kept) all[line]];
    bool onKept(Rect rect) =>
        bands.first.top <= rect.center.dy && rect.center.dy < bands.last.bottom;

    final words = <QuranAddress, Rect>{};
    final marks = <(QuranAddress, int), Rect>{};
    final markers = <QuranAddress, Rect>{};
    for (final number in layout.ayat) {
      final from = plan.lineOfAyahText(number) - firstLine;
      final to = plan.lineOfAyahEnd(number) - firstLine;
      if (to < kept.first || from > kept.last) continue;
      final ayah = plan.text.addressOf(number);
      final text = plan.text.ayat[number - 1];
      for (final word in text.words) {
        final rect = layout.wordBox(number, word.number);
        if (rect != null && onKept(rect)) {
          words[QuranAddress(ayah.riwaya, ayah.surah, number, word.number)] =
              rect;
        }
      }
      for (final mark in text.marks) {
        // A mark that shares its box with the token before it can span two
        // lines; the mark itself is on the last.
        final boxes = layout.markBoxes(number, mark.number);
        if (boxes.isNotEmpty && onKept(boxes.last)) {
          marks[(ayah, mark.number)] = boxes.last;
        }
      }
      if (layout.markerRect(number) case final marker? when onKept(marker)) {
        markers[ayah] = marker;
      }
    }
    return TargetGeometry(
      lineBands: bands,
      words: words,
      marks: marks,
      markers: markers,
    );
  }

  final List<Rect> lineBands;
  final Map<QuranAddress, Rect> words;

  /// Mark boxes by ayah and mark number, for the marks that have one.
  final Map<(QuranAddress, int), Rect> marks;
  final Map<QuranAddress, Rect> markers;

  /// The index of the band holding [y], or null off every band.
  int? bandAt(double y) {
    for (final (k, band) in lineBands.indexed) {
      if (band.top <= y && y < band.bottom) return k;
    }
    return null;
  }
}
