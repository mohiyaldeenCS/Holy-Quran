import 'package:flutter/painting.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

// The tafsir reader is a full screen the identity does not draw
// (docs/DESIGN_SYSTEM.md, "Screens": new extension). It follows «خطة الحفظ»
// of Search.dc.html, the drawn screen pushed from a hub with a back button,
// as the resource manager does. Nothing else is measured: the rest is tokens
// and the design-system widgets.

/// Search.dc.html, «خطة الحفظ» header: `padding:24px 16px 8px`.
const EdgeInsetsDirectional tafsirHeaderPadding =
    EdgeInsetsDirectional.fromSTEB(
      AppSpacing.space4,
      AppSpacing.space5,
      AppSpacing.space4,
      AppSpacing.space2,
    );

/// Search.dc.html, «خطة الحفظ» header: `gap:10px`.
const double tafsirHeaderGap = 10;

/// Search.dc.html, «خطة الحفظ» title: `font-size:22px;font-weight:700` in
/// the body's IBM Plex Sans Arabic with its `normal` line height.
const TextStyle tafsirTitleStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 22,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// Search.dc.html, «خطة الحفظ» body: `padding:0 20px`.
const EdgeInsetsDirectional tafsirBodyPadding = EdgeInsetsDirectional.symmetric(
  horizontal: 20,
);

/// The steps between ayat stand under the list, which the board has no
/// counterpart for: they take the body's `padding:0 20px` at the sides and
/// the `space-3` token above and below.
const EdgeInsetsDirectional tafsirStepsPadding =
    EdgeInsetsDirectional.symmetric(
      horizontal: 20,
      vertical: AppSpacing.space3,
    );

/// The rows of the default-tafsir list have no corners, so neither has their
/// focus ring, as the rows of the copy sheet (Share.dc.html, the copy forms).
const BorderRadius tafsirChoiceFocusRadius = BorderRadius.zero;
