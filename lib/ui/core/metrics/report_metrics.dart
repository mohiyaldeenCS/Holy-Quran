import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The report sheet, an extension (PRD §7.6) on the identity's bottom sheet
/// (`.qk-sheet` in `design/design-system/components/bundle.css`, as
/// `WordSheet` draws it).
abstract final class ReportMetrics {
  // .qk-sheet: padding var(--space-3) 22px 22px.
  static const EdgeInsets sheetPadding = EdgeInsets.fromLTRB(
    _sheetSide,
    AppSpacing.space3,
    _sheetSide,
    _sheetSide,
  );

  // .qk-sheet: border-radius var(--radius-sheet) var(--radius-sheet) 0 0.
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(AppRadius.radiusSheet),
  );

  // .qk-sheet: gap var(--space-4).
  static const double sheetGap = AppSpacing.space4;

  // .qk-sheet-handle: width 44px; height 5px.
  static const Size handleSize = Size(44, 5);

  // .qk-sheet-handle: border-radius 3px.
  static const BorderRadius handleRadius = BorderRadius.all(Radius.circular(3));

  static const double _sheetSide = 22;
}
