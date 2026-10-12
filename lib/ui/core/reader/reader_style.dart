import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The type and placeholder sizes of surah-mode text under one text scaler:
/// `quran-page` (25/2.3, `docs/DESIGN_SYSTEM.md`, "Type"), right to left, in
/// Arabic, every line forced to the style's height by a strut so that every
/// line of a surah is one height, a line holding only a page mark too.
final class ReaderStyle {
  ReaderStyle(this.scaler) : _space = _spaceAdvance(scaler);

  final TextScaler scaler;
  final double _space;

  static const TextStyle text = AppTextStyles.quranPage;

  static const Locale locale = Locale('ar');

  /// The advance of U+0020 in this style: the gap on each side of an inline
  /// mark, which stands for the space the board writes around each marker
  /// (`Screens.dc.html`, the surah-mode text) without adding a character.
  double get markGap => _space;

  /// The `AyahMarker` diameter, which follows the text scale (D-057).
  double get markerDiameter => scaler.scale(AppSizes.ayahMarker);

  /// The one size of every inline placeholder, a marker with a gap on each
  /// side. SkParagraph reorders the placeholders of a right-to-left line
  /// (S1 finding 1), which is undone only when all are one size, so a page
  /// mark is held to a marker's place.
  Size get slot => Size(_space + markerDiameter + _space, markerDiameter);

  /// Where a placeholder's baseline lies below its top: its centre half the
  /// x-height above the text baseline, as `.qk-ayah-no`'s
  /// `vertical-align: middle` puts it.
  double get slotBaseline =>
      slot.height / 2 + scaler.scale(text.fontSize!) * _quranXHeight / 2;

  ui.ParagraphStyle paragraphStyle({TextAlign align = TextAlign.start}) =>
      text.getParagraphStyle(
        textAlign: align,
        textDirection: TextDirection.rtl,
        textScaler: scaler,
        locale: locale,
        strutStyle: _strut,
      );

  /// The run style of surah-mode text: [color] (none for measuring), and
  /// [fontScale] times the size for a word that would not fit its line whole.
  ui.TextStyle runStyle({
    Color? color,
    double wordSpacing = 0,
    double fontScale = 1,
  }) => text
      .copyWith(
        color: color,
        wordSpacing: wordSpacing,
        fontSize: text.fontSize! * fontScale,
        locale: locale,
      )
      .getTextStyle(textScaler: scaler);

  void addSlot(ui.ParagraphBuilder builder) => builder.addPlaceholder(
    slot.width,
    slot.height,
    ui.PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    baselineOffset: slotBaseline,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderStyle && other.scaler == scaler;

  @override
  int get hashCode => scaler.hashCode;

  static double _spaceAdvance(TextScaler scaler) {
    final painter = TextPainter(
      text: const TextSpan(text: _spaceCharacter, style: text, locale: locale),
      textDirection: TextDirection.rtl,
      locale: locale,
      textScaler: scaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  static final StrutStyle _strut = StrutStyle.fromTextStyle(
    text,
    forceStrutHeight: true,
  );
}

const String _spaceCharacter = ' ';

// .qk-ayah-no `vertical-align: middle` centres the marker half the parent's
// x-height above the baseline: AmiriQuran-Regular.ttf, OS/2 sxHeight 433 of
// unitsPerEm 1000 (S1 finding 5). Flutter's PlaceholderAlignment.middle
// centres it in the line box instead, about 9 px higher at 25 px.
const double _quranXHeight = 0.433;
