import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/metrics/settings_metrics.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// Screen metrics of the index and the sheets that go with it, read from the
/// index screen of `design/identity-boards/Screens2.dc.html` (lines 21 to 37).
abstract final class IndexMetrics {
  // Screens2.dc.html l.21, the header: `padding:28px 20px 10px`, shared with
  // the other tab roots (D-134).
  static const EdgeInsets header = SettingsMetrics.tabRootHeader;

  // Screens2.dc.html l.21, the header: `gap:14px` between the title row, the
  // search field and the tabs.
  static const double headerGap = 14;

  // Screens2.dc.html l.22, the summary: `font-size:14px` in the body's family
  // at 400, no line height, in #51605D (`ink-muted`).
  static const TextStyle summaryStyle = TextStyle(
    inherit: false,
    fontFamily: AppFonts.sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // Screens2.dc.html l.30, the list: `padding:0 20px`.
  static const EdgeInsets list = EdgeInsets.symmetric(horizontal: 20);

  // The end of the list, clear of the tab bar's shadow.
  static const double listEnd = AppSpacing.space5;

  // Screens2.dc.html l.31, the row: `gap:14px;padding:12px 0`, the vertical
  // padding being `space-3`. The juz, hizb and rub rows follow it.
  static const double rowGap = 14;
  static const EdgeInsets rowPadding = EdgeInsets.symmetric(
    vertical: AppSpacing.space3,
  );

  // Screens2.dc.html l.32, the number: a 44 box holding the quarter star
  // (`width="44" … stroke-width="4"`).
  static const double numberBox = 44;
  static const double numberStroke = 4;

  // Screens2.dc.html l.32, the number's digits: `font-size:14px;
  // font-weight:600`, in #8A6212 (`accent`).
  static const TextStyle numberStyle = TextStyle(
    inherit: false,
    fontFamily: AppFonts.sans,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // Screens2.dc.html l.33, the middle column: `gap:2px`.
  static const double mainGap = 2;

  // Screens2.dc.html l.34, the name: Reem Kufi, `font-size:20px;
  // font-weight:600;line-height:1.4`, in #1B2A28 (`ink`).
  static const TextStyle titleStyle = TextStyle(
    inherit: false,
    fontFamily: AppFonts.kufi,
    fontFamilyFallback: [AppFonts.sans],
    fontSize: 20,
    height: 1.4,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // Screens2.dc.html l.35, the meta line: `font-size:14px` in #51605D
  // (`ink-muted`), no line height.
  static const TextStyle metaStyle = summaryStyle;

  // Screens2.dc.html l.37, the page column: `min-width:40px`; the word is
  // `font-size:12px` in `ink-muted`, the number `font-size:16px;
  // font-weight:600` in `ink`.
  static const double pageMinWidth = 40;
  static const TextStyle pageWordStyle = TextStyle(
    inherit: false,
    fontFamily: AppFonts.sans,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
  static const TextStyle pageNumberStyle = TextStyle(
    inherit: false,
    fontFamily: AppFonts.sans,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // The digits are sized from the star and not scaled again: a non-linear
  // system text scale would enlarge 14 proportionally more than 44 and push
  // them out of it.
  static TextStyle numberStyleIn(double box) =>
      numberStyle.copyWith(fontSize: box * numberStyle.fontSize! / numberBox);

  // The board's rows have no corners, so neither has their focus ring.
  static const BorderRadius rowFocusRadius = BorderRadius.zero;

  // A rub row sits under its hizb's row, set in from the row's start. The
  // identity draws no such row; the step is a spacing token.
  static EdgeInsetsDirectional rowInset({required bool rub}) =>
      EdgeInsetsDirectional.only(start: rub ? AppSpacing.space5 : 0);
}
