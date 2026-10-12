import 'package:flutter/painting.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// Screen metrics of the home screen, read from the home board of
/// `design/identity-boards/Screens.dc.html`.
abstract final class HomeMetrics {
  // The header row: `padding:28px 20px 8px`.
  static const EdgeInsetsDirectional headerPadding =
      EdgeInsetsDirectional.fromSTEB(
        _sideInset,
        _headerTop,
        _sideInset,
        AppSpacing.space2,
      );

  // The content under the header: `padding:12px 20px 0`.
  static const EdgeInsetsDirectional bodyPadding =
      EdgeInsetsDirectional.fromSTEB(
        _sideInset,
        AppSpacing.space3,
        _sideInset,
        0,
      );

  // The content column: `gap:14px` between the greeting, the card and the
  // doors.
  static const double sectionGap = 14;

  // The greeting block: `padding:4px 0 2px`.
  static const EdgeInsetsDirectional greetingPadding =
      EdgeInsetsDirectional.only(top: AppSpacing.space1, bottom: 2);

  // The greeting line: `font-size:14px` in the body's IBM Plex Sans Arabic at
  // 400, with no line height set, so the font's own (CSS `normal`). Its
  // colour, #51605D, is `ink-muted`. The heading under it, 28 / 1.4 / 700,
  // is `screen-title`.
  static const TextStyle greetingStyle = TextStyle(
    fontFamily: AppFonts.sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // The doors: `grid-template-columns:repeat(4, minmax(0, 1fr));gap:8px`,
  // the gap being `space-2`.
  static const int doorColumns = 4;

  static const double _sideInset = 20;
  static const double _headerTop = 28;
}
