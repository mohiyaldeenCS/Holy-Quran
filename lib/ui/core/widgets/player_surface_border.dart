import 'package:flutter/material.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';

/// The border of every surface drawn in the identity's `player` colour, in
/// night and contrast, where that colour is the page's own (contrast) or
/// nearly (night), so the surface would not stand apart (D-140). `line-strong`
/// is drawn at 3:1 on `ground` and `surface`, and is the contrast theme's white
/// border between surfaces (tokens.md l.87–88); 1px is the identity's border
/// width (bundle.css l.33, l.71). Paper and sepia keep the surface as the
/// boards draw it.
Border? playerSurfaceBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Border.all(color: context.colors.lineStrong)
    : null;
