import 'package:flutter/painting.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The Quran font size at which [ayah] fills [box] whole (WG-03): the first
/// of [from], [from] - 1, ... down to [to] at which it is no taller than
/// [box] and no word is wider; null when none, and the widget skips the ayah.
///
/// [box] is `AyahWidgetFace.ayahBoxOf` of the face's size.
double? fitQuranSize(
  PackText ayah,
  Size box, {
  double from = 28,
  double to = 22,
}) {
  assert(to >= _cardMinFontSize, 'QuranText.card asserts at least 22');
  assert(from >= to, 'from must not be below to');
  for (var size = from; size >= to; size--) {
    final painter = _layOut(ayah, size, box.width);
    final fits =
        painter.height <= box.height && painter.minIntrinsicWidth <= box.width;
    painter.dispose();
    if (fits) return size;
  }
  return null;
}

/// The size [ayah] takes in `QuranText.card` at [fontSize], [width] wide:
/// what [fitQuranSize] measures.
Size widgetAyahSize(PackText ayah, double fontSize, double width) {
  final painter = _layOut(ayah, fontSize, width);
  final size = painter.size;
  painter.dispose();
  return size;
}

/// [ayah] set exactly as `QuranText.card` sets it.
TextPainter _layOut(PackText ayah, double fontSize, double width) =>
    TextPainter(
      // Spike only: measuring reads the text here, outside the sinks of D-062.
      // A widget form of QuranText that measures itself is Phase 2.
      text: TextSpan(
        text: ayah.verbatim,
        style: _quranCard.copyWith(fontSize: fontSize),
        locale: _arabic,
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      locale: _arabic,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: width);

const Locale _arabic = Locale('ar');

// lib/ui/core/widgets/quran_text.dart, `_quranCard`: Share.dc.html's card
// ayah with `line-height: 2.2` (D-085); the widget's line 91 draws 2.
const TextStyle _quranCard = TextStyle(
  fontFamily: AppFonts.quran,
  height: 2.2,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

// lib/ui/core/widgets/quran_text.dart, `_cardMinFontSize` (D-089, 1).
const double _cardMinFontSize = 22;
