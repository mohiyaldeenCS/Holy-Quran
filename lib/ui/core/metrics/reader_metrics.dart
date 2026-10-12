/// Surah-mode metrics the boards draw that are not tokens
/// (docs/DESIGN_SYSTEM.md, "Metrics that are not tokens").
abstract final class ReaderMetrics {
  /// The reader's text column, `padding: 18px 28px 0`, its sides
  /// (`Screens.dc.html`, the surah-mode reader).
  static const double textInset = 28;

  /// The reader's text column, `gap: 22px`, between its parts
  /// (`Screens.dc.html`). That board draws al-Fatiha, which has no separate
  /// basmala; the same gap below the basmala line is a reading.
  static const double sectionGap = 22;

  /// The quarter star in the margin, `width="40"` (`Mushaf.dc.html`,
  /// «الأرباع والأحزاب»).
  static const double marginStar = 40;

  /// Between the margin star and its words, `gap: 8px` (`Mushaf.dc.html`,
  /// «الأرباع والأحزاب»).
  static const double marginStarGap = 8;

  /// The margin words «ربع» and «الحزب», `font-size: 14px; font-weight: 600;
  /// line-height: 1.3` (`Mushaf.dc.html`, «الأرباع والأحزاب»); «سجدة» takes
  /// the same size and weight with no line height («موضع السجدة»).
  static const double marginLabelSize = 14;
  static const double marginLabelHeight = 1.3;

  /// The juz's name in the margin, Reem Kufi `font-size: 20px; font-weight:
  /// 600` over `border-bottom: 2px solid` gold with `padding-bottom: 2px`
  /// (`Mushaf.dc.html`, «بداية الجزء»).
  static const double juzNameSize = 20;
  static const double juzRule = 2;
  static const double juzRuleGap = 2;
}
