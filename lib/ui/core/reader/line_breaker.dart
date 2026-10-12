import 'dart:math' as math;

/// A unit's place: its ayah index from 0 and its index in the ayah.
typedef UnitPosition = ({int ayah, int unit});

/// What line breaking needs of a unit: its natural width with the marker
/// slot after an ayah's last unit, and the natural width of the space after
/// it in its ayah. A page mark is a unit of its own, a slot with no space
/// after it, so that a line may break on either side of it.
final class UnitWidths {
  const UnitWidths(this.width, {this.gapAfter = 0, this.spaceAfter = false});

  final double width;
  final double gapAfter;

  /// Whether a space follows, which a justified line stretches.
  final bool spaceAfter;
}

/// One line of a surah, from unit [start] to unit [end] inclusive.
/// [stretch] is the spacing added to each of its [gaps] (the spaces between
/// its units within an ayah) to justify it; 0 on the last line, which is
/// centred. Units are counted from an ayah's page mark when it has one.
final class PlannedLine {
  const PlannedLine(
    this.start,
    this.end,
    this.natural,
    this.gaps,
    this.stretch,
  );

  final UnitPosition start;
  final UnitPosition end;
  final double natural;
  final int gaps;
  final double stretch;

  bool holds(int ayah, int unit) =>
      _compare((ayah: ayah, unit: unit), start) >= 0 &&
      _compare((ayah: ayah, unit: unit), end) <= 0;

  static int _compare(UnitPosition a, UnitPosition b) =>
      a.ayah != b.ayah ? a.ayah - b.ayah : a.unit - b.unit;
}

/// Breaks the units of [ayat], in order, into lines no wider than [width],
/// only between units (`WQ-01`): each line takes as many units as fit, and
/// a unit wider than the line stands alone. Every line but the last is
/// justified by sharing what is left among its gaps; a line with no gap
/// keeps to the start.
List<PlannedLine> breakLines(List<List<UnitWidths>> ayat, double width) {
  final spans = <(UnitPosition, UnitPosition, double, int)>[];
  UnitPosition? start;
  UnitPosition? last;
  var natural = 0.0;
  var gaps = 0;
  for (final (a, units) in ayat.indexed) {
    for (final (k, unit) in units.indexed) {
      final position = (ayah: a, unit: k);
      if (start != null && last != null) {
        final before = last.ayah == a ? ayat[a][k - 1] : null;
        final candidate = natural + (before?.gapAfter ?? 0) + unit.width;
        if (candidate <= width) {
          natural = candidate;
          if (before?.spaceAfter ?? false) gaps++;
          last = position;
          continue;
        }
        spans.add((start, last, natural, gaps));
      }
      start = position;
      last = position;
      natural = unit.width;
      gaps = 0;
    }
  }
  if (start != null && last != null) spans.add((start, last, natural, gaps));
  return List.unmodifiable([
    for (final (index, (first, end, natural, gaps)) in spans.indexed)
      PlannedLine(
        first,
        end,
        natural,
        gaps,
        index == spans.length - 1 || gaps == 0
            ? 0
            : math.max(0.0, width - natural) / gaps,
      ),
  ]);
}

/// The width a segment paragraph is laid out at: a little more than the
/// line, so that a justified line, exactly the line's width by the sum of
/// its measured parts, never wraps on a rounding difference. Painting moves
/// the paragraph back by the same amount.
double paragraphWidth(double width) => width + paragraphSlack;

const double paragraphSlack = 1;

/// A word spacing no line can hold: given to the space after a line's last
/// unit, it makes the paragraph break exactly there.
double forcedBreakSpacing(double width) => 2 * paragraphWidth(width);
