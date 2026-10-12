import 'break_units.dart';
import 'surah_text.dart';

/// How one ayah, or the part of it one paragraph holds, is set: per unit,
/// the word spacing of the space that follows it (the stretch of its
/// justified line, or a spacing no line holds, which forces the break after
/// it), the font scale of a unit that would not fit its line whole, and the
/// paragraph line it is on. [number] counts from 1.
final class PlannedAyah {
  const PlannedAyah({
    required this.number,
    required this.ayah,
    required this.units,
    required this.pageMark,
    required this.firstUnit,
    required this.endUnit,
    required this.spacing,
    required this.fontScales,
    required this.lines,
    required this.pageSlot,
    required this.markerSlot,
  });

  final int number;
  final AyahText ayah;
  final AyahUnits units;

  /// Whether this paragraph holds the page mark before the ayah, inside the
  /// line (D-071).
  final bool pageMark;

  /// The units of the ayah's text this paragraph holds, [firstUnit]
  /// inclusive, [endUnit] exclusive; [spacing] and [lines] hold one entry
  /// for each.
  final int firstUnit;
  final int endUnit;
  final List<double> spacing;

  /// One per unit of the whole ayah.
  final List<double> fontScales;
  final List<int> lines;

  /// The widths of the page mark's and the marker's slots: a slot's gaps
  /// stretch with its line.
  final double pageSlot;
  final double markerSlot;

  bool get hasText => endUnit > firstUnit;

  /// Whether this paragraph holds the ayah's last unit, and so its marker.
  bool get hasMarker => hasText && endUnit == units.units.length;

  /// Where the text this paragraph holds starts and ends in the ayah: its
  /// units with the space after the last of them.
  int get textStart => units.units[firstUnit].start;
  int get textEnd => hasMarker ? units.length : units.units[endUnit].start;
}
