import 'dart:ui' as ui;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';

import 'break_units.dart';
import 'planned_ayah.dart';
import 'reader_style.dart';
import 'surah_text.dart';

// The one pack-text sink of the surah-mode engine (D-113, D-114). Pack values
// are placed whole, side by side, and sliced only at stored word and mark
// offsets and at the spaces between them; the slices of an ayah, in order,
// are its stored text. Nothing is added, replaced or removed: a marker, a
// page mark and the gaps around them are placeholders, and a line break is
// forced by spacing, never by a character.

/// The length in UTF-16 code units of [text], for cutting it into units.
int packTextLength(PackText text) => text.verbatim.length;

/// The natural widths of an ayah set alone on one line: per unit, then per
/// gap. Ayat shape independently of each other, since the marker between
/// them is a placeholder, so these are the widths the ayah has in any
/// paragraph that holds it whole with the same [fontScales].
final class AyahMeasure {
  const AyahMeasure(this.units, this.gaps, this.height);

  final List<double> units;
  final List<double> gaps;

  /// The height of one line.
  final double height;
}

AyahMeasure measureAyah(
  AyahText ayah,
  AyahUnits units,
  ReaderStyle style, {
  List<double>? fontScales,
}) {
  final value = ayah.text.verbatim;
  final builder = ui.ParagraphBuilder(style.paragraphStyle());
  for (final (k, unit) in units.units.indexed) {
    builder
      ..pushStyle(style.runStyle(fontScale: fontScales?[k] ?? 1))
      ..addText(value.substring(unit.start, unit.end))
      ..pop();
    if (k < units.gaps.length) {
      final (start, end) = units.gaps[k];
      builder
        ..pushStyle(style.runStyle())
        ..addText(value.substring(start, end))
        ..pop();
    }
  }
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: double.infinity));
  paragraph.layout(
    ui.ParagraphConstraints(width: paragraph.maxIntrinsicWidth + _measureRoom),
  );
  double widthOf(int start, int end) => paragraph
      .getBoxesForRange(start, end)
      .fold(0.0, (sum, box) => sum + box.right - box.left);
  final measure = AyahMeasure(
    [for (final unit in units.units) widthOf(unit.start, unit.end)],
    [for (final (start, end) in units.gaps) widthOf(start, end)],
    paragraph.height,
  );
  paragraph.dispose();
  return measure;
}

/// One run of a segment paragraph, in order: a slice of an ayah's pack text
/// with its style, or an inline slot.
sealed class SegmentRun {
  const SegmentRun(this.ayah);

  /// The ayah it belongs to, numbered from 1.
  final int ayah;
}

/// A slice of the ayah's stored text, cut at stored offsets.
final class TextRun extends SegmentRun {
  const TextRun(super.ayah, this.text, this.style);

  final String text;
  final ui.TextStyle style;
}

/// The slot of the ayah's marker or of the page mark before it.
final class SlotRun extends SegmentRun {
  const SlotRun(super.ayah, {required this.pageMark, required this.width});

  final bool pageMark;
  final double width;
}

/// The runs of one segment: ayat or parts of them, each preceded by its
/// page mark slot when the segment holds it and followed by its marker slot
/// when it holds the ayah's end, every unit in the colour [colourOfLine]
/// gives its line. An ayah's text runs over all segments, joined, are its
/// stored text.
List<SegmentRun> segmentRuns(
  List<PlannedAyah> ayat,
  ReaderStyle style, {
  required Color Function(int line) colourOfLine,
}) => [
  for (final planned in ayat) ...[
    if (planned.pageMark)
      SlotRun(planned.number, pageMark: true, width: planned.pageSlot),
    ..._ayahRuns(planned, style, colourOfLine),
    if (planned.hasMarker)
      SlotRun(planned.number, pageMark: false, width: planned.markerSlot),
  ],
];

/// The paragraph of one segment's [segmentRuns], laid out at [width].
ui.Paragraph buildSegment(
  List<PlannedAyah> ayat,
  ReaderStyle style,
  double width, {
  required Color Function(int line) colourOfLine,
}) {
  final builder = ui.ParagraphBuilder(style.paragraphStyle());
  for (final run in segmentRuns(ayat, style, colourOfLine: colourOfLine)) {
    switch (run) {
      case TextRun(:final text, style: final runStyle):
        builder
          ..pushStyle(runStyle)
          ..addText(text)
          ..pop();
      case SlotRun(:final width):
        style.addSlot(builder, width);
    }
  }
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

Iterable<TextRun> _ayahRuns(
  PlannedAyah planned,
  ReaderStyle style,
  Color Function(int line) colourOfLine,
) sync* {
  final value = planned.ayah.text.verbatim;
  final units = planned.units;
  TextRun? slice(int start, int end, ui.TextStyle run) => start == end
      ? null
      : TextRun(planned.number, value.substring(start, end), run);

  for (var k = planned.firstUnit; k < planned.endUnit; k++) {
    final unit = units.units[k];
    final colour = colourOfLine(planned.lines[k - planned.firstUnit]);
    final spacing = planned.spacing[k - planned.firstUnit];
    final fontScale = planned.fontScales[k];
    // SkParagraph spaces a space by the word spacing of the cluster before it
    // on a right-to-left run, and only when the space's own style asks for
    // some. So the unit's tokens carry the spacing, the spaces inside it
    // none, and the gap after it asks for the unit's.
    final plain = style.runStyle(color: colour, fontScale: fontScale);
    final spaced = style.runStyle(
      color: colour,
      wordSpacing: spacing,
      fontScale: fontScale,
    );
    var at = unit.start;
    for (final (start, end) in unit.tokens) {
      if (slice(at, start, plain) case final run?) yield run;
      if (slice(start, end, spaced) case final run?) yield run;
      at = end;
    }
    if (slice(at, unit.end, plain) case final run?) yield run;
    if (k < units.gaps.length) {
      final (start, end) = units.gaps[k];
      final gap = style.runStyle(color: colour, wordSpacing: spacing);
      if (slice(start, end, gap) case final run?) yield run;
    }
  }
}

/// The height of [basmala] as `QuranText` draws it at [width], centred on
/// its own line (`RD-02`).
double basmalaHeight(PackText basmala, ReaderStyle style, double width) {
  final painter = TextPainter(
    text: TextSpan(
      text: basmala.verbatim,
      style: ReaderStyle.text,
      locale: ReaderStyle.locale,
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.rtl,
    locale: ReaderStyle.locale,
    textScaler: style.scaler,
  )..layout(maxWidth: width);
  final height = painter.height;
  painter.dispose();
  return height;
}

/// What a screen reader reads for an ayah: its stored text, at [order]
/// among the block's text, markers and page marks.
Widget ayahSemantics(AyahText ayah, double order) => Semantics(
  container: true,
  label: ayah.text.verbatim,
  textDirection: TextDirection.rtl,
  sortKey: OrdinalSortKey(order),
  child: const SizedBox.expand(),
);

// Room past the ayah's natural width, so that the one line it is measured on
// never wraps on a rounding difference.
const double _measureRoom = 1;
