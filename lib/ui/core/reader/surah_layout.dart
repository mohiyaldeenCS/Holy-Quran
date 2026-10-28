import 'dart:math' as math;

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/metrics/reader_metrics.dart';

import 'break_units.dart';
import 'line_breaker.dart';
import 'planned_ayah.dart';
import 'reader_paragraph.dart';
import 'reader_style.dart';
import 'surah_text.dart';

/// Where a line starts in pack terms: the ayah index from 0 and a UTF-16
/// offset into its text; -1 when the line starts with the ayah's page mark.
typedef LineStart = ({int ayah, int offset});

/// A run of lines set as one paragraph. A line that ends at a space is
/// forced to break there by spacing; any other line ends its paragraph: one
/// that ends with an ayah's marker or a page mark, and the line of a unit
/// drawn smaller, which is a run of its own and would not take the spacing.
/// So no break needs a character.
final class Segment {
  const Segment(
    this.firstLine,
    this.endLine,
    this.firstAyah,
    this.endAyah, {
    required this.endsAyah,
  });

  /// Surah line indices, [firstLine] inclusive, [endLine] exclusive.
  final int firstLine;
  final int endLine;

  /// Ayah indices from 0, [firstAyah] inclusive, [endAyah] exclusive.
  final int firstAyah;
  final int endAyah;

  /// Whether it ends at an ayah's marker or a page mark, where a block may
  /// end: an ayah's text is never split between blocks.
  final bool endsAyah;

  int get lineCount => endLine - firstLine;
}

/// Consecutive segments laid out and scrolled as one sliver child.
final class Block {
  const Block(this.firstSegment, this.endSegment, this.firstLine, this.endLine);

  final int firstSegment;
  final int endSegment;
  final int firstLine;
  final int endLine;

  int get lineCount => endLine - firstLine;
}

/// The plan of a surah's text at one width and text scale: where every line
/// breaks, how each is justified, and how lines group into segments and
/// blocks. Only measuring is done here; blocks are laid out when shown
/// (`BlockLayout`), so a long surah opens without laying out its text.
///
/// Every line has one height (the style's strut), so a line's place is its
/// index times [lineHeight], and positions are known before layout.
final class SurahLayout {
  SurahLayout._(
    this.text,
    this.style,
    this.width,
    this.lineHeight,
    this.basmalaExtent,
    this._units,
    this._leads,
    this._fontScales,
    this.lines,
    this.segments,
    this.blocks,
  );

  /// Plans [text] at [width] with [style]; blocks hold about [blockLines]
  /// lines.
  factory SurahLayout.plan(
    SurahText text,
    ReaderStyle style,
    double width, {
    int blockLines = defaultBlockLines,
  }) {
    final slot = style.slot.width;
    final units = <AyahUnits>[];
    final leads = <int>[];
    final fontScales = <List<double>>[];
    final measures = <List<UnitWidths>>[];
    var lineHeight = 0.0;
    for (final (index, ayah) in text.ayat.indexed) {
      final ayahUnits = AyahUnits.of(
        packTextLength(ayah.text),
        ayah.words,
        ayah.marks,
      );
      final count = ayahUnits.units.length;
      final slots = [
        for (var k = 0; k < count; k++) k == count - 1 ? slot : 0.0,
      ];
      final (measure, scales) = _measureWhole(
        ayah,
        ayahUnits,
        style,
        width,
        slots,
      );
      lineHeight = math.max(lineHeight, measure.height);
      final pageMark = text.pageStarts.containsKey(index + 1);
      units.add(ayahUnits);
      leads.add(pageMark ? 1 : 0);
      fontScales.add(scales);
      measures.add([
        if (pageMark) UnitWidths(slot, endsWithSlot: true),
        for (var k = 0; k < count; k++)
          UnitWidths(
            measure.units[k] + slots[k],
            gapAfter: k < measure.gaps.length ? measure.gaps[k] : 0,
            spaceAfter: k < measure.gaps.length,
            endsWithSlot: k == count - 1,
          ),
      ]);
    }
    final lines = breakLines(measures, width, hang: style.markGap);
    final segments = _segments(lines, units, leads, fontScales);
    final basmala = text.basmala;
    return SurahLayout._(
      text,
      style,
      width,
      lineHeight,
      text.showsBasmala && basmala != null
          ? basmalaHeight(basmala, style, width) + ReaderMetrics.sectionGap
          : 0,
      units,
      leads,
      fontScales,
      lines,
      segments,
      _blocks(segments, blockLines),
    );
  }

  final SurahText text;
  final ReaderStyle style;
  final double width;
  final double lineHeight;

  /// The basmala's line with the gap below it, or 0 when the surah shows
  /// none: the top of the text.
  final double basmalaExtent;
  final List<AyahUnits> _units;

  /// Per ayah, 1 when its page mark is its first unit, else 0.
  final List<int> _leads;
  final List<List<double>> _fontScales;
  final List<PlannedLine> lines;
  final List<Segment> segments;
  final List<Block> blocks;

  double blockHeight(int block) => blocks[block].lineCount * lineHeight;

  /// The top of [block] in the surah's sliver.
  double blockTop(int block) =>
      basmalaExtent + blocks[block].firstLine * lineHeight;

  /// The height of the surah's sliver: the basmala and the text.
  double get height => basmalaExtent + lines.length * lineHeight;

  /// The line on which the ayah of [ayah] (numbered from 1) begins: the
  /// line of its page mark when it has one.
  int lineOfAyah(int ayah) {
    final index = ayah - 1;
    if (index < 0 || index >= text.ayat.length) {
      throw RangeError.range(ayah, 1, text.ayat.length, 'ayah');
    }
    var low = 0;
    var high = lines.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      final start = lines[middle].start;
      if (start.ayah < index || (start.ayah == index && start.unit == 0)) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }

  /// The line on which the text of the ayah of [ayah] (numbered from 1)
  /// begins.
  int lineOfAyahText(int ayah) => _lineHolding(ayah - 1, _leads[ayah - 1]);

  /// The line on which the ayah of [ayah] (numbered from 1) ends.
  int lineOfAyahEnd(int ayah) {
    final index = ayah - 1;
    return _lineHolding(index, _leads[index] + _units[index].units.length - 1);
  }

  int _lineHolding(int index, int unit) => lines.indexWhere(
    (line) => line.holds(index, unit),
    lineOfAyah(index + 1),
  );

  /// Where line [line] starts by the plan.
  LineStart lineStart(int line) {
    final start = lines[line].start;
    final text = start.unit - _leads[start.ayah];
    return (
      ayah: start.ayah,
      offset: text < 0 ? -1 : _units[start.ayah].units[text].start,
    );
  }

  /// The top of the line on which the ayah of [address] begins in the
  /// surah's sliver: where to scroll to restore a position or jump to an
  /// address.
  double offsetOf(QuranAddress address) {
    if (address.riwaya != text.riwaya || address.surah != text.surah) {
      throw ArgumentError.value(address, 'address', 'is not in this surah');
    }
    return basmalaExtent + lineOfAyah(address.ayah) * lineHeight;
  }

  /// The ayah a reader is at when [offset] into the surah's sliver is the
  /// top of the screen: the ayah of the first line still showing, the one
  /// the line continues when it starts inside an ayah.
  QuranAddress ayahAt(double offset) {
    final line = ((offset - basmalaExtent) / lineHeight).floor().clamp(
      0,
      lines.length - 1,
    );
    return text.addressOf(lines[line].start.ayah + 1);
  }

  /// The block holding the text of the ayah of [ayah] (numbered from 1).
  int blockOfAyah(int ayah) {
    final line = lineOfAyahText(ayah);
    return blocks.indexWhere((block) => line < block.endLine);
  }

  /// How the ayat of [segment] are set in its paragraph: an ayah whose
  /// page mark ends a line has its page mark in one segment and its text in
  /// the next.
  List<PlannedAyah> plannedAyat(Segment segment) => [
    for (var index = segment.firstAyah; index < segment.endAyah; index++)
      ?_planned(segment, index),
  ];

  PlannedAyah? _planned(Segment segment, int index) {
    bool inSegment(int line) =>
        line >= segment.firstLine && line < segment.endLine;
    final lead = _leads[index];
    final pageMark = lead == 1 && inSegment(lineOfAyah(index + 1));
    final units = _units[index];
    final spacing = <double>[];
    final lineOf = <int>[];
    int? firstUnit;
    var line = lineOfAyah(index + 1);
    for (var k = 0; k < units.units.length; k++) {
      while (!lines[line].holds(index, k + lead)) {
        line++;
      }
      if (!inSegment(line)) continue;
      firstUnit ??= k;
      final planned = lines[line];
      lineOf.add(line - segment.firstLine);
      final endsLine = planned.end == (ayah: index, unit: k + lead);
      spacing.add(
        endsLine && k < units.gaps.length
            ? forcedBreakSpacing(width, style.markGap)
            : planned.stretch,
      );
    }
    if (!pageMark && firstUnit == null) return null;
    double slotOn(int line) => style.slot.width + 2 * lines[line].stretch;
    return PlannedAyah(
      number: index + 1,
      ayah: text.ayat[index],
      units: units,
      pageMark: pageMark,
      firstUnit: firstUnit ?? 0,
      endUnit: (firstUnit ?? 0) + lineOf.length,
      spacing: spacing,
      fontScales: _fontScales[index],
      lines: lineOf,
      pageSlot: slotOn(lineOfAyah(index + 1)),
      markerSlot: slotOn(lineOfAyahEnd(index + 1)),
    );
  }

  /// The width [segment]'s paragraph is laid out at: the line's width, the
  /// slack, and room for the overhang of its lines.
  double paragraphWidthOf(Segment segment) {
    var overhang = 0.0;
    for (var line = segment.firstLine; line < segment.endLine; line++) {
      overhang = math.max(overhang, overhangOf(lines[line], style.markGap));
    }
    return width + paragraphSlack + overhang;
  }

  /// The ayah measured, with any unit wider than [width] drawn smaller so
  /// that it fits its line whole (D-091 item 12 for the word sheet; here
  /// D-113). Its size is narrowed until it fits, since the system scaler
  /// may not scale in proportion.
  static (AyahMeasure, List<double>) _measureWhole(
    AyahText ayah,
    AyahUnits units,
    ReaderStyle style,
    double width,
    List<double> slots,
  ) {
    var measure = measureAyah(ayah, units, style);
    final scales = List<double>.filled(units.units.length, 1);
    for (var round = 0; round < _fitRounds; round++) {
      var changed = false;
      for (var k = 0; k < scales.length; k++) {
        // Narrower than a marker's place, a line cannot hold the word and
        // its marker at any size; the word then keeps its size.
        final room = width - slots[k];
        final drawn = measure.units[k];
        if (drawn > room && drawn > 0 && room > 0) {
          scales[k] *= room / drawn * _fitMargin;
          changed = true;
        }
      }
      if (!changed) break;
      measure = measureAyah(ayah, units, style, fontScales: scales);
    }
    return (measure, List.unmodifiable(scales));
  }

  /// Splits [lines] into paragraphs after every line that ends with no space
  /// to force its break: at an ayah's marker, after a page mark, and around
  /// the line of a unit drawn smaller.
  static List<Segment> _segments(
    List<PlannedLine> lines,
    List<AyahUnits> units,
    List<int> leads,
    List<List<double>> fontScales,
  ) {
    bool scaled(UnitPosition at) {
      final unit = at.unit - leads[at.ayah];
      return unit >= 0 && fontScales[at.ayah][unit] != 1;
    }

    final segments = <Segment>[];
    var first = 0;
    for (var k = 0; k < lines.length; k++) {
      final end = lines[k].end;
      final last = leads[end.ayah] + units[end.ayah].units.length - 1;
      final endsAyah =
          end.unit == last || (leads[end.ayah] == 1 && end.unit == 0);
      final splits =
          endsAyah ||
          scaled(end) ||
          (k + 1 < lines.length && scaled(lines[k + 1].start));
      if (splits) {
        segments.add(
          Segment(
            first,
            k + 1,
            lines[first].start.ayah,
            end.ayah + 1,
            endsAyah: endsAyah,
          ),
        );
        first = k + 1;
      }
    }
    return List.unmodifiable(segments);
  }

  static List<Block> _blocks(List<Segment> segments, int blockLines) {
    final blocks = <Block>[];
    var first = 0;
    for (var k = 0; k < segments.length; k++) {
      final lineCount = segments[k].endLine - segments[first].firstLine;
      if ((lineCount >= blockLines && segments[k].endsAyah) ||
          k == segments.length - 1) {
        blocks.add(
          Block(first, k + 1, segments[first].firstLine, segments[k].endLine),
        );
        first = k + 1;
      }
    }
    return List.unmodifiable(blocks);
  }
}

/// About a screen of lines per block: small enough to lay out within a
/// frame while scrolling (S1: 5 to 16 ms for a page-sized block in debug).
const int defaultBlockLines = 16;

// A unit too wide for its line is narrowed in at most this many rounds, each
// to just under the room left.
const int _fitRounds = 4;
const double _fitMargin = 0.995;
