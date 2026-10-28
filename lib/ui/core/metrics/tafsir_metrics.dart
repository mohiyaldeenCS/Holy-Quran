import 'package:flutter/painting.dart';

import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

// The tafsir reader is a full screen the identity does not draw
// (docs/DESIGN_SYSTEM.md, "Screens": new extension). It follows «خطة الحفظ»
// of Search.dc.html, the drawn screen pushed from a hub with a back button,
// as the resource manager does. Nothing else is measured: the rest is tokens
// and the design-system widgets.

/// The header, the title and the body of «خطة الحفظ» are the resource
/// manager's: one source, `resources_metrics.dart`, which cites the board.
const EdgeInsetsDirectional tafsirHeaderPadding = resourcesHeaderPadding;
const double tafsirHeaderGap = resourcesHeaderGap;
const TextStyle tafsirTitleStyle = resourcesTitleStyle;
const EdgeInsetsDirectional tafsirBodyPadding = resourcesBodyPadding;

/// The steps between ayat stand under the list, which the board has no
/// counterpart for: they take the body's `padding:0 20px` at the sides and
/// the `space-3` token above and below.
const EdgeInsetsDirectional tafsirStepsPadding =
    EdgeInsetsDirectional.symmetric(
      horizontal: 20,
      vertical: AppSpacing.space3,
    );
