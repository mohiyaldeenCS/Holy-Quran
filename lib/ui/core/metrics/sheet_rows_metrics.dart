import 'package:flutter/painting.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

// `.qk-sheet-rows` (bundle.css): the sunk box of `WordSheet`'s rows, which the
// note of a bookmarks card and the notes of the mini ayah sheet take too.

/// `.qk-sheet-rows`: `border-radius: 20px`.
const BorderRadius sheetRowsRadius = BorderRadius.all(Radius.circular(20));

/// `.qk-sheet-rows`: `padding: 4px 18px`, the 4 being `space-1`.
const double sheetRowsInsetX = 18;
const double sheetRowsInsetY = AppSpacing.space1;
const EdgeInsets sheetRowsPadding = EdgeInsets.symmetric(
  horizontal: sheetRowsInsetX,
  vertical: sheetRowsInsetY,
);
