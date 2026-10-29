import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/metrics/settings_metrics.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// Screen metrics of the search screen, read from the first phone of
/// `design/identity-boards/Search.dc.html`. The scope row and the history are
/// not drawn there; they use only the board's gaps and the tokens.
abstract final class SearchMetrics {
  // Search.dc.html, the header: `padding:24px 16px 8px; gap:10px`.
  static const EdgeInsets header = SettingsMetrics.header;
  static const double headerGap = 10;

  // Search.dc.html, the header's title: `font-size:22px; font-weight:700` in
  // the body's family, no line height.
  static const TextStyle titleStyle = TextStyle(
    inherit: false,
    fontFamily: AppFonts.sans,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // Search.dc.html, the controls: `padding:0 20px; gap:12px`, the gap being
  // `space-3`.
  static const EdgeInsets controls = EdgeInsets.symmetric(horizontal: 20);
  static const double controlsGap = AppSpacing.space3;

  // The Search board keeps the field, the chips and the summary fixed and
  // scrolls only the results. Controls taller than this share of the height
  // scroll with the results instead (a decision of the lead, 2026-10-29).
  static const double pinnedShare = 0.5;

  // Search.dc.html, the summary row: `padding-top:2px`.
  static const EdgeInsets summary = EdgeInsets.only(top: 2);

  // Search.dc.html, the results: `padding:12px 20px 0; gap:10px`. The end is
  // a spacing token, as the index list's is: the board draws no end.
  static const EdgeInsets results = EdgeInsets.fromLTRB(
    20,
    12,
    20,
    AppSpacing.space5,
  );
  static const double resultGap = 10;

  // The history rows and the sentence of an empty result use the results'
  // padding and the controls' gap.
  static const EdgeInsets history = results;
  static const double historyGap = AppSpacing.space3;
}
