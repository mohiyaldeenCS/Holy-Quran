import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import 'block_layout.dart';
import 'highlight_painter.dart';
import 'highlight_shapes.dart';
import 'reader_highlights.dart';

/// The layers of [highlights] that go under a block's text, as children of
/// the block's `Stack`: the tints and lines, painted from its geometry.
List<Widget> highlightsUnder(
  BuildContext context,
  BlockLayout layout,
  ReaderHighlights highlights,
) {
  final shapes = highlightShapes(layout, highlights);
  if (shapes.isEmpty) return const [];
  return [
    Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: HighlightPainter(shapes, context.colors)),
      ),
    ),
  ];
}

/// The layer that goes over a block's text: the marker of the ayah being
/// recited, filled. It covers the block's own marker of that ayah and is
/// left out of semantics, which already read the marker once.
List<Widget> highlightsOver(
  BuildContext context,
  BlockLayout layout,
  ReaderHighlights highlights,
) {
  final text = layout.plan.text;
  final recited = highlights.recitedAyah;
  if (recited == null ||
      recited.riwaya != text.riwaya ||
      recited.surah != text.surah) {
    return const [];
  }
  final rect = layout.markerRect(recited.ayah);
  if (rect == null) return const [];
  return [
    Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: layout.plan.style.scaler),
            child: AyahMarker(number: recited.ayah, playing: true),
          ),
        ),
      ),
    ),
  ];
}
