import 'dart:math' as math;

/// A unit's place: its ayah index from 0 and its index in the ayah.
typedef UnitPosition = ({int ayah, int unit});

/// What line breaking needs of a unit: its natural width with the marker
/// slot after an ayah's last unit, and the natural width of the space after
/// it in its ayah. A page mark is a unit of its own, a slot with no space
/// after it, so that a line may break on either side of it. [endsWithSlot]
/// marks a unit that ends with a slot: a marker or a page mark.
final class UnitWidths {
  const UnitWidths(
    this.width, {
    this.gapAfter = 0,
    this.spaceAfter = false,
    this.endsWithSlot = false,
  });

  final double width;
  final double gapAfter;

  /// Whether a space follows, which a justified line stretches.
  final bool spaceAfter;
  final bool endsWithSlot;
}

/// One line of a surah, from unit [start] to unit [end] inclusive, counted
/// from an ayah's page mark when it has one.
///
/// A slot stands for a marker or page mark with the board's space on each
/// side (`Screens.dc.html`), so a justified line stretches those two gaps as
/// it stretches its [gaps], by [stretch] each, and a slot that ends the line
/// lets its far gap hang past the edge, as `text-align: justify` lets a
/// line's last space hang. [stretch] is 0 on the last line, which is
/// centred.
final class PlannedLine {
  const PlannedLine(
    this.start,
    this.end,
    this.natural,
    this.gaps,
    this.slots,
    this.stretch, {
    required this.endsWithSlot,
  });

  final UnitPosition start;
  final UnitPosition end;
  final double natural;
  final int gaps;
  final int slots;
  final double stretch;
  final bool endsWithSlot;

  bool holds(int ayah, int unit) =>
      _compare((ayah: ayah, unit: unit), start) >= 0 &&
      _compare((ayah: ayah, unit: unit), end) <= 0;

  static int _compare(UnitPosition a, UnitPosition b) =>
      a.ayah != b.ayah ? a.ayah - b.ayah : a.unit - b.unit;
}

/// Breaks the units of [ayat], in order, into lines no wider than [width],
/// only between units (`WQ-01`): each line takes as many units as fit, the
/// far gap ([hang]) of a slot that ends it not counted, and a unit wider
/// than the line stands alone. Every line but the last is justified; a line
/// with nothing to stretch keeps to the start.
List<PlannedLine> breakLines(
  List<List<UnitWidths>> ayat,
  double width, {
  required double hang,
}) {
  final spans = <(UnitPosition, UnitPosition, double, int, int, bool)>[];
  UnitPosition? start;
  UnitPosition? last;
  var natural = 0.0;
  var gaps = 0;
  var slots = 0;
  var endsWithSlot = false;
  double fits(double natural, bool endsWithSlot) =>
      natural - (endsWithSlot ? hang : 0);
  for (final (a, units) in ayat.indexed) {
    for (final (k, unit) in units.indexed) {
      final position = (ayah: a, unit: k);
      final unitSlots = (unit.endsWithSlot ? 1 : 0);
      if (start != null && last != null) {
        final before = last.ayah == a ? ayat[a][k - 1] : null;
        final candidate = natural + (before?.gapAfter ?? 0) + unit.width;
        if (fits(candidate, unit.endsWithSlot) <= width) {
          natural = candidate;
          if (before?.spaceAfter ?? false) gaps++;
          slots += unitSlots;
          endsWithSlot = unit.endsWithSlot;
          last = position;
          continue;
        }
        spans.add((start, last, natural, gaps, slots, endsWithSlot));
      }
      start = position;
      last = position;
      natural = unit.width;
      gaps = 0;
      slots = unitSlots;
      endsWithSlot = unit.endsWithSlot;
    }
  }
  if (start != null && last != null) {
    spans.add((start, last, natural, gaps, slots, endsWithSlot));
  }
  return List.unmodifiable([
    for (final (index, (first, end, natural, gaps, slots, endsWithSlot))
        in spans.indexed)
      PlannedLine(
        first,
        end,
        natural,
        gaps,
        slots,
        _stretch(
          room: width - fits(natural, endsWithSlot),
          stretchable: gaps + 2 * slots - (endsWithSlot ? 1 : 0),
          last: index == spans.length - 1,
        ),
        endsWithSlot: endsWithSlot,
      ),
  ]);
}

double _stretch({
  required double room,
  required int stretchable,
  required bool last,
}) => last || stretchable == 0 ? 0 : math.max(0.0, room) / stretchable;

/// How far a line reaches past its width on the left: the far gap of a slot
/// that ends it, stretched with the line.
double overhangOf(PlannedLine line, double hang) =>
    line.endsWithSlot ? hang + line.stretch : 0;

/// The slack a segment paragraph is laid out with beyond its lines, so that
/// a justified line, exactly its width by the sum of its measured parts,
/// never wraps on a rounding difference.
const double paragraphSlack = 1;

/// A word spacing no line can hold: given to the space after a line's last
/// unit, it makes the paragraph break exactly there. A line with its
/// overhang is at most twice the width and twice the gap.
double forcedBreakSpacing(double width, double hang) =>
    4 * (width + hang + paragraphSlack);
