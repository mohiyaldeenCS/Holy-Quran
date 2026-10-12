/// The sizes of a share card (SH-02): the width of the drawn 4:5 card, the
/// height from the ratio (D-089, 2).
enum ShareCardRatio {
  square(1, 1),
  portrait(4, 5),
  tall(9, 16);

  const ShareCardRatio(this.width, this.height);

  final int width;
  final int height;

  /// The card's height when it is [cardWidth] wide.
  double heightFor(double cardWidth) => cardWidth * height / width;
}

/// The size and font size a share card is drawn at, or none (SH-03).
sealed class ShareCardFit {
  const ShareCardFit();
}

/// The ayah fits whole on the card of [ratio] at [fontSize].
final class ShareCardFits extends ShareCardFit {
  const ShareCardFits(this.ratio, this.fontSize);

  final ShareCardRatio ratio;
  final double fontSize;

  @override
  bool operator ==(Object other) =>
      other is ShareCardFits &&
      other.ratio == ratio &&
      other.fontSize == fontSize;

  @override
  int get hashCode => Object.hash(ratio, fontSize);

  @override
  String toString() => 'ShareCardFits(${ratio.name}, $fontSize)';
}

/// The ayah fits on no card, even the tall one at the least size.
final class ShareCardTooLong extends ShareCardFit {
  const ShareCardTooLong();

  @override
  bool operator ==(Object other) => other is ShareCardTooLong;

  @override
  int get hashCode => (ShareCardTooLong).hashCode;

  @override
  String toString() => 'ShareCardTooLong()';
}

/// Whether the whole ayah fits on the card of [ratio] at [fontSize].
typedef ShareCardFitTest = bool Function(ShareCardRatio ratio, double fontSize);

/// SH-03: the largest font size from the card's own down to the least that
/// fits at [chosen]; failing that, the same on the tall card; failing that,
/// [ShareCardTooLong]. The ayah is never cut or joined with another.
ShareCardFit fitShareCard(ShareCardRatio chosen, ShareCardFitTest fits) {
  for (final ratio in {chosen, ShareCardRatio.tall}) {
    for (
      var fontSize = shareCardFontSize;
      fontSize >= shareCardLeastFontSize;
      fontSize -= _fontStep
    ) {
      if (fits(ratio, fontSize)) return ShareCardFits(ratio, fontSize);
    }
  }
  return const ShareCardTooLong();
}

/// The card's own font size: D-089 (1), the emerald card on Share.dc.html,
/// `font-size:34px`.
const double shareCardFontSize = 34;

/// D-089 (1) and SH-03: the ayah shrinks to 22 at the least.
const double shareCardLeastFontSize = 22;

// SH-03 gives no step; whole pixels, as the board's 34, 26 and 23 are.
const double _fontStep = 1;
