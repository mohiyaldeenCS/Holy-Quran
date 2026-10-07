import 'package:flutter/material.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

final Map<ReadingTheme, ThemeData> _themes = {};

/// The Material theme for one reading theme. Every colour Material would
/// otherwise take from its own palette is mapped by role from [AppColors].
ThemeData buildAppTheme(ReadingTheme theme) =>
    _themes.putIfAbsent(theme, () => _build(theme));

ThemeData _build(ReadingTheme theme) {
  final colors = AppColors.byId[theme.name]!;
  final shadows = AppShadows.byId[theme.name]!;
  final brightness = switch (theme) {
    ReadingTheme.paper || ReadingTheme.sepia => Brightness.light,
    ReadingTheme.night || ReadingTheme.contrast => Brightness.dark,
  };
  // The reference defines no pressed, hover or Material elevation look; depth
  // comes from AppShadows only.
  final none = colors.ground.withValues(alpha: 0);

  final base = ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primarySoft,
      onPrimaryContainer: colors.onPrimarySoft,
      secondary: colors.accent,
      onSecondary: colors.ground,
      error: colors.error,
      onError: colors.ground,
      surface: colors.surface,
      onSurface: colors.ink,
      onSurfaceVariant: colors.inkMuted,
      surfaceDim: colors.surfaceSunk,
      surfaceContainerHighest: colors.surfaceSunk,
      outline: colors.lineStrong,
      outlineVariant: colors.line,
      inverseSurface: colors.ink,
      onInverseSurface: colors.surface,
      shadow: none,
      scrim: colors.scrim,
      surfaceTint: none,
    ),
    scaffoldBackgroundColor: colors.ground,
    canvasColor: colors.ground,
    cardColor: colors.surface,
    primaryColor: colors.primary,
    primaryColorLight: colors.primarySoft,
    primaryColorDark: colors.onPrimarySoft,
    secondaryHeaderColor: colors.surfaceSunk,
    dividerColor: colors.line,
    disabledColor: colors.inkDisabled,
    hintColor: colors.inkMuted,
    unselectedWidgetColor: colors.inkMuted,
    shadowColor: none,
    splashFactory: NoSplash.splashFactory,
    splashColor: none,
    highlightColor: none,
    hoverColor: none,
    focusColor: none,
    fontFamily: AppFonts.sans,
    textTheme: TextTheme(
      bodyMedium: AppTextStyles.body.copyWith(color: colors.ink),
    ),
    iconTheme: IconThemeData(color: colors.ink, size: AppSizes.iconSize),
    primaryIconTheme: IconThemeData(
      color: colors.onPrimary,
      size: AppSizes.iconSize,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.primary,
      selectionColor: colors.selection,
      selectionHandleColor: colors.primary,
    ),
    extensions: [colors, shadows],
  );
  // Arabic is never letter-spaced: every identity style has letterSpacing 0,
  // and Material's own slots must not add any.
  return base.copyWith(
    textTheme: base.textTheme.merge(_unspaced),
    primaryTextTheme: base.primaryTextTheme
        .merge(_unspaced)
        .apply(bodyColor: colors.onPrimary, displayColor: colors.onPrimary),
  );
}

const TextStyle _noLetterSpacing = TextStyle(letterSpacing: 0);

const TextTheme _unspaced = TextTheme(
  displayLarge: _noLetterSpacing,
  displayMedium: _noLetterSpacing,
  displaySmall: _noLetterSpacing,
  headlineLarge: _noLetterSpacing,
  headlineMedium: _noLetterSpacing,
  headlineSmall: _noLetterSpacing,
  titleLarge: _noLetterSpacing,
  titleMedium: _noLetterSpacing,
  titleSmall: _noLetterSpacing,
  bodyLarge: _noLetterSpacing,
  bodyMedium: _noLetterSpacing,
  bodySmall: _noLetterSpacing,
  labelLarge: _noLetterSpacing,
  labelMedium: _noLetterSpacing,
  labelSmall: _noLetterSpacing,
);
