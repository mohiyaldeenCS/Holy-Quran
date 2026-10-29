import 'package:flutter/painting.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

// The resource manager is described, not drawn (docs/DESIGN_SYSTEM.md,
// "Screens"). It follows «خطة الحفظ» of Search.dc.html, the drawn list
// screen pushed from a hub with a back button, and its sheet follows
// `.qk-sheet`.

/// Search.dc.html, «خطة الحفظ» header: `padding:24px 16px 8px`.
const EdgeInsetsDirectional resourcesHeaderPadding =
    EdgeInsetsDirectional.fromSTEB(
      AppSpacing.space4,
      AppSpacing.space5,
      AppSpacing.space4,
      AppSpacing.space2,
    );

/// Search.dc.html, «خطة الحفظ» header: `gap:10px`.
const double resourcesHeaderGap = 10;

/// Search.dc.html, «خطة الحفظ» title: `font-size:22px;font-weight:700` in
/// the body's IBM Plex Sans Arabic with its `normal` line height.
const TextStyle resourcesTitleStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 22,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// Search.dc.html, «خطة الحفظ» body: `padding:0 20px`.
const EdgeInsetsDirectional resourcesBodyPadding =
    EdgeInsetsDirectional.symmetric(horizontal: 20);

/// Search.dc.html, «خطة الحفظ» body: `gap:12px` between blocks.
const double resourcesBlockGap = AppSpacing.space3;

/// `.qk-sheet`: `padding: var(--space-3) 22px 22px`.
const EdgeInsetsDirectional resourcesSheetPadding =
    EdgeInsetsDirectional.fromSTEB(22, AppSpacing.space3, 22, 22);

/// `.qk-sheet`: `border-radius: var(--radius-sheet) var(--radius-sheet) 0 0`.
const BorderRadius resourcesSheetRadius = BorderRadius.vertical(
  top: Radius.circular(AppRadius.radiusSheet),
);

/// `.qk-sheet`: `gap: var(--space-4)`.
const double resourcesSheetGap = AppSpacing.space4;

/// `.qk-sheet-handle`: `width: 44px; height: 5px`.
const Size resourcesSheetHandleSize = Size(44, 5);

/// `.qk-sheet-handle`: `border-radius: 3px`.
const BorderRadius resourcesSheetHandleRadius = BorderRadius.all(
  Radius.circular(3),
);

/// `.qk-resource`: `padding: 14px 0`, under the alert a pack's row adds below
/// `ResourceRow`, as `ResourceRow` keeps it under its own lines.
const EdgeInsetsDirectional resourcesRowFootPadding =
    EdgeInsetsDirectional.only(bottom: 14);

// A recitation's scope rows (P1-33) are `ResourceRow`'s own layout with a
// widget for the title, so that a surah's name reaches the screen through
// `SurahName` only. The values below are `ResourceRow`'s (index.jsx and
// `.qk-resource`), which keeps them private.

/// `.qk-resource`: `padding: 14px 0`.
const double scopeRowPaddingVertical = 14;

/// `.qk-resource-main`: `gap: 6px`.
const double scopeRowMainGap = 6;

/// `ResourceRow` in index.jsx: `<Icon name="check" size={16} />`.
const double scopeRowCheckSize = 16;

/// `.qk-resource-title`: `font-size:17px; font-weight:600`, the body's IBM
/// Plex Sans Arabic with its `normal` line height.
const TextStyle scopeRowTitleStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 17,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// `.qk-resource-meta`: `font-size:14px`.
final TextStyle scopeRowMetaStyle = scopeRowTitleStyle.copyWith(
  fontSize: 14,
  fontWeight: FontWeight.w400,
);

/// `.qk-resource-meta.is-done`: `font-weight:500`.
final TextStyle scopeRowDoneMetaStyle = scopeRowMetaStyle.copyWith(
  fontWeight: FontWeight.w500,
);

/// `.qk-resource-pct`: `font-size:15px; font-weight:600`.
final TextStyle scopeRowPercentStyle = scopeRowTitleStyle.copyWith(
  fontSize: 15,
);

/// The gap between the blocks of a recitation's panel: the strip of
/// qualities, the strip of lists and the rows. The identity draws no such
/// panel; the gap is the sections' own (`resourcesBlockGap`).
const double recitationPanelGap = resourcesBlockGap;

/// A scope row's vertical padding as `ResourceRow` pads it.
const EdgeInsetsDirectional scopeRowPadding = EdgeInsetsDirectional.symmetric(
  vertical: scopeRowPaddingVertical,
);

/// A fraction of a download as the whole percent `ResourceRow` writes.
int percentOf(double fraction) => (fraction.clamp(0.0, 1.0) * 100).round();

/// How often the files of a recitation on the device are counted again while
/// a download adds to them: a count looks at every file, so it is not made at
/// each tick of the progress.
const Duration recitationCountEvery = Duration(seconds: 2);
