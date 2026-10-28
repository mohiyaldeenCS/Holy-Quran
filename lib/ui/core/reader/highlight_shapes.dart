import 'package:flutter/painting.dart';

import 'package:holyquran/domain/models/quran_address.dart';

import 'block_layout.dart';
import 'reader_highlights.dart';
import 'reader_style.dart';
import 'surah_layout.dart';

/// Which highlight a [HighlightShape] belongs to, in the order they are
/// painted: the word over the ayah it is in.
enum HighlightKind { recitedAyah, selectedAyah, searchMatch, spokenWord }

/// One rect of a highlight, in block coordinates: an ayah has one for each
/// line it covers, a word one.
typedef HighlightShape = ({HighlightKind kind, Rect rect});

// `.qk-hl-ayah` and `.qk-hl-select`: `padding: 0 4px`.
const double _ayahInset = 4;

/// The rects of [highlights] that fall in [layout], from its text geometry
/// alone: no text is read. Each is as tall as the font's own box and not the
/// line, as the board's inline backgrounds are (`.qk-hl-*`), and an ayah's
/// grows by the board's 4 px on each side.
List<HighlightShape> highlightShapes(
  BlockLayout layout,
  ReaderHighlights highlights,
) {
  if (highlights.isEmpty) return const [];
  final text = layout.plan.text;
  final (:top, :height) = _fontBoxOf(layout.plan);

  Rect fontBox(Rect band, {double inset = 0}) => Rect.fromLTRB(
    band.left - inset,
    band.top + top,
    band.right + inset,
    band.top + top + height,
  );
  bool here(QuranAddress? address) =>
      address != null &&
      address.riwaya == text.riwaya &&
      address.surah == text.surah;

  return [
    if (highlights.recitedAyah case final ayah? when here(ayah))
      for (final box in layout.ayahBoxes(ayah.ayah))
        (
          kind: HighlightKind.recitedAyah,
          rect: fontBox(box, inset: _ayahInset),
        ),
    if (highlights.selectedAyah case final ayah? when here(ayah))
      for (final box in layout.ayahBoxes(ayah.ayah))
        (
          kind: HighlightKind.selectedAyah,
          rect: fontBox(box, inset: _ayahInset),
        ),
    for (final word in highlights.searchMatches)
      if (here(word) && word.word != null)
        if (layout.wordBox(word.ayah, word.word!) case final box?)
          (kind: HighlightKind.searchMatch, rect: fontBox(box)),
    if (highlights.spokenWord case final word? when here(word) && word.isWord)
      if (layout.wordBox(word.ayah, word.word!) case final box?)
        (kind: HighlightKind.spokenWord, rect: fontBox(box)),
  ];
}

// The font's box depends on the plan alone, and a plan's blocks rebuild
// often: measure it once per plan.
final Expando<({double top, double height})> _fontBoxes = Expando();

({double top, double height}) _fontBoxOf(SurahLayout plan) =>
    _fontBoxes[plan] ??= _fontBox(plan.style, plan.lineHeight);

/// The font's own box inside a line of [lineHeight]: its top below the line's
/// top and its height. `quran-page` spreads its leading evenly, so the box
/// sits in the middle of the line.
({double top, double height}) _fontBox(ReaderStyle style, double lineHeight) {
  final painter = TextPainter(
    text: TextSpan(
      text: ' ',
      style: TextStyle(
        fontFamily: ReaderStyle.text.fontFamily,
        fontSize: ReaderStyle.text.fontSize,
      ),
      locale: ReaderStyle.locale,
    ),
    textDirection: TextDirection.rtl,
    textScaler: style.scaler,
  )..layout();
  final metrics = painter.computeLineMetrics().first;
  painter.dispose();
  final height = (metrics.ascent + metrics.descent).clamp(0.0, lineHeight);
  return (top: (lineHeight - height) / 2, height: height);
}
