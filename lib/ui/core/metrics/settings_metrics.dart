import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The layout of the screens P1-15 adds as extensions (PRD §7.6): settings,
/// the More hub and the first-run setup, from
/// `design/identity-boards/Screens2.dc.html`. A pushed screen follows the
/// player screen, its header row and the column of content under it; the
/// More hub, a tab's first screen, takes the index screen's header.
abstract final class SettingsMetrics {
  // Screens2.dc.html, player screen header: `padding:24px 16px 8px`.
  static const EdgeInsets header = EdgeInsets.fromLTRB(
    AppSpacing.space4,
    AppSpacing.space5,
    AppSpacing.space4,
    AppSpacing.space2,
  );

  // Screens2.dc.html, index screen header: `padding:28px 20px 10px`.
  static const EdgeInsets tabRootHeader = EdgeInsets.fromLTRB(
    _contentSide,
    28,
    _contentSide,
    10,
  );

  // Screens2.dc.html, player screen content: `padding:4px 20px 0`.
  static const EdgeInsets content = EdgeInsets.fromLTRB(
    _contentSide,
    AppSpacing.space1,
    _contentSide,
    0,
  );

  // Screens2.dc.html, player screen content: `gap:12px`.
  static const double contentGap = AppSpacing.space3;

  static const double _contentSide = 20;
}
