import 'package:flutter/painting.dart';

import 'package:holyquran/ui/core/metrics/sheet_rows_metrics.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

// The mini ayah sheet is not drawn (docs/DESIGN_SYSTEM.md, "Screens";
// PRD §7.4). It takes the copy sheet's frame (`CopySheetFrame`, Share.dc.html)
// and is composed of `AyahRow`, `Button`, `SourceBadge` and the tafsir text;
// its sections are spaced with the tokens. The word sheet is drawn
// (`WordSheet`) and keeps its own constants.

/// Space above each section after the ayah: the `space-3` token, besides the
/// frame's own gap. The identity draws no section break in a sheet.
const EdgeInsets ayahSheetSectionPadding = EdgeInsets.only(
  top: AppSpacing.space3,
);

/// Between a section's heading and its content, and between its blocks: the
/// `space-3` token, the gap the board's lists keep between their blocks.
const double ayahSheetContentGap = AppSpacing.space3;

/// A note of the user's, drawn as the notes of the bookmarks list are: the
/// box of `.qk-sheet-rows` (radius and insets shared in
/// `sheet_rows_metrics.dart`) with the row's `padding: var(--space-3) 0`
/// inside it, as `.qk-sheet-row` sits in `.qk-sheet-rows`.
const double ayahSheetNoteRowInsetY = AppSpacing.space3;
const EdgeInsets ayahSheetNotePadding = EdgeInsets.symmetric(
  horizontal: sheetRowsInsetX,
  vertical: sheetRowsInsetY + ayahSheetNoteRowInsetY,
);
