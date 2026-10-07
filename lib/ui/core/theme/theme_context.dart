import 'package:flutter/material.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';

extension ThemeTokens on BuildContext {
  AppColors get colors => _require(Theme.of(this).extension<AppColors>());

  AppShadows get shadows => _require(Theme.of(this).extension<AppShadows>());
}

T _require<T>(T? extension) =>
    extension ??
    (throw StateError(
      '$T is missing from the theme. Build the theme with buildAppTheme().',
    ));
