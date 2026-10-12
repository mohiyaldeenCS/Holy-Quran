/// Surah-mode metrics the boards draw that are not tokens
/// (docs/DESIGN_SYSTEM.md, "Metrics that are not tokens").
abstract final class ReaderMetrics {
  /// The reader's text column, `padding: 18px 28px 0`, its sides
  /// (`Screens.dc.html`, the surah-mode reader).
  static const double textInset = 28;

  /// The reader's text column, `gap: 22px`: between the surah header, the
  /// basmala and the text (`Screens.dc.html`).
  static const double sectionGap = 22;

  /// «رقم الصفحة», the page number, `font-size: 15px; font-weight: 600` in
  /// the gold of the page's marks (`Mushaf.dc.html`, «تشريح الصفحة»): the
  /// number of a page mark inside the line (D-071).
  static const double pageNumberSize = 15;

  /// The quarter star in the margin, `width="40"` (`Mushaf.dc.html`,
  /// «الأرباع والأحزاب»).
  static const double marginStar = 40;

  /// Between the margin star and its words, `gap: 8px` (`Mushaf.dc.html`,
  /// «الأرباع والأحزاب»).
  static const double marginStarGap = 8;

  /// The margin words «ربع» and «الحزب», `font-size: 14px; font-weight: 600;
  /// line-height: 1.3` (`Mushaf.dc.html`, «الأرباع والأحزاب»); «سجدة» takes
  /// the same size and weight («موضع السجدة»).
  static const double marginLabelSize = 14;
  static const double marginLabelHeight = 1.3;
}
