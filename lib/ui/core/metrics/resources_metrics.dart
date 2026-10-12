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

/// `.qk-resource-main`: `gap: 6px`, between the lines a pack's row adds
/// below `ResourceRow` (its source, its update, its alert).
const double resourcesRowLineGap = 6;

/// `.qk-resource`: `padding: 14px 0`, under those lines, as `ResourceRow`
/// keeps it under its own.
const EdgeInsetsDirectional resourcesRowFootPadding =
    EdgeInsetsDirectional.only(bottom: 14);
