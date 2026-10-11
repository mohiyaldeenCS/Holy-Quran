import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'native_shaping_probe.dart';

/// [sample] laid out by Flutter as the probe lays it out natively: the Quran
/// font at weight 400, no line height, Arabic, right to left, no text scale.
ShapingMeasure measureFlutterShaping(
  ShapingSample sample, {
  required double fontSize,
  required double maxWidth,
}) {
  final text = shapingSampleText(sample);
  final style = TextStyle(
    fontFamily: AppFonts.quran,
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    locale: const Locale('ar'),
  );
  final builder =
      ui.ParagraphBuilder(
          style.getParagraphStyle(
            textDirection: TextDirection.rtl,
            locale: const Locale('ar'),
          ),
        )
        ..pushStyle(style.getTextStyle())
        ..addText(text);
  final paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: maxWidth));
  try {
    final lines = paragraph.computeLineMetrics();
    final lineStarts = <int>[];
    var line = -1;
    for (var offset = 0; offset < text.length; offset++) {
      final at = paragraph.getLineNumberAt(offset);
      if (at != null && at != line) {
        lineStarts.add(offset);
        line = at;
      }
    }
    final lineWidths = [for (final metrics in lines) metrics.width];
    return (
      width: lineWidths.fold(0, math.max),
      height: paragraph.height,
      lineCount: lines.length,
      lineStarts: lineStarts,
      lineWidths: lineWidths,
    );
  } finally {
    paragraph.dispose();
  }
}

/// How the native layout differs from Flutter's: each delta is native minus
/// Flutter. Deltas only; what counts as close enough is decided after the
/// device run (D-096).
typedef ShapingComparison = ({
  double widthDelta,
  double heightDelta,
  int lineCountDelta,

  /// The first line whose start differs, or that only one layout has.
  int? firstMovedLine,

  /// Per line both layouts have.
  List<double> lineWidthDeltas,
  bool fontMatches,
});

ShapingComparison compareShaping(
  ShapingMeasure flutter,
  ShapingMeasure native, {
  required bool fontMatches,
}) {
  final common = math.min(flutter.lineStarts.length, native.lineStarts.length);
  int? firstMovedLine;
  for (var i = 0; i < common; i++) {
    if (flutter.lineStarts[i] != native.lineStarts[i]) {
      firstMovedLine = i;
      break;
    }
  }
  if (firstMovedLine == null &&
      flutter.lineStarts.length != native.lineStarts.length) {
    firstMovedLine = common;
  }
  final widths = math.min(flutter.lineWidths.length, native.lineWidths.length);
  return (
    widthDelta: native.width - flutter.width,
    heightDelta: native.height - flutter.height,
    lineCountDelta: native.lineCount - flutter.lineCount,
    firstMovedLine: firstMovedLine,
    lineWidthDeltas: [
      for (var i = 0; i < widths; i++)
        native.lineWidths[i] - flutter.lineWidths[i],
    ],
    fontMatches: fontMatches,
  );
}
