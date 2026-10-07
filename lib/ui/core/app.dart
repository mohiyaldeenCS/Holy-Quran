import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';

class QuranApp extends StatelessWidget {
  const QuranApp({
    required this.router,
    this.themePreference = const ThemePreference(),
    super.key,
  });

  final GoRouter router;
  final ThemePreference themePreference;

  @override
  Widget build(BuildContext context) {
    final follow = themePreference.followSystemDark;
    return MaterialApp.router(
      routerConfig: router,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
      // A chosen light slot may hold night or contrast: buildAppTheme sets the
      // brightness, so ThemeMode only decides whether the system is followed.
      theme: buildAppTheme(themePreference.theme),
      darkTheme: follow
          ? buildAppTheme(themePreference.resolve(systemIsDark: true))
          : null,
      themeMode: follow ? ThemeMode.system : ThemeMode.light,
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemBarsFor(
          Theme.of(context).brightness,
          ground: context.colors.ground,
        ),
        child: child!,
      ),
    );
  }
}

/// System bars on the theme's ground, with icons that stay legible on it.
SystemUiOverlayStyle _systemBarsFor(
  Brightness brightness, {
  required Color ground,
}) {
  final icons = brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarBrightness: brightness,
    statusBarIconBrightness: icons,
    systemNavigationBarColor: ground,
    systemNavigationBarIconBrightness: icons,
  );
}
