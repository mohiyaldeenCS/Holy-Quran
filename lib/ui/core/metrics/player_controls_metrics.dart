import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The player's control sheets are extensions (`docs/DESIGN_SYSTEM.md`,
/// "Screens"). They follow the identity's drawn sheets, `WordSheet` and
/// `ContextSheet`, whose frame is `.qk-sheet` in
/// `design/design-system/components/bundle.css`; these are its values.
abstract final class PlayerControlsMetrics {
  // .qk-sheet: border-radius var(--radius-sheet) var(--radius-sheet) 0 0.
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(AppRadius.radiusSheet),
  );

  // The focus ring is drawn 4px outside a control (`:focus-visible`:
  // outline 2px, offset 2px). The sheet's scrolling content is inset by it,
  // so a scroll view that clips leaves the ring whole; the sheet's padding
  // and first gap give it back.
  static const double focusRingRoom = AppSpacing.space1;
  static const EdgeInsets scrollPadding = EdgeInsets.all(focusRingRoom);

  // .qk-sheet: padding var(--space-3) 22px 22px, less the ring's room.
  static const EdgeInsets sheetPadding = EdgeInsets.fromLTRB(
    22 - focusRingRoom,
    AppSpacing.space3,
    22 - focusRingRoom,
    22 - focusRingRoom,
  );

  // .qk-sheet: gap var(--space-4), less the 4px above and below a ModeChips
  // strip that `.qk-chips { padding: 4px 2px; margin: -4px -2px }` takes
  // back.
  static const double chipStripGap = AppSpacing.space4 - AppSpacing.space1;

  // .qk-sheet-row: padding var(--space-3) 0; a queue row is one.
  static const EdgeInsets sheetRowPadding = EdgeInsets.symmetric(
    vertical: AppSpacing.space3,
  );

  // .qk-sheet-handle: width 44px; height 5px; border-radius 3px.
  static const Size handleSize = Size(44, 5);
  static const BorderRadius handleRadius = BorderRadius.all(Radius.circular(3));
}
