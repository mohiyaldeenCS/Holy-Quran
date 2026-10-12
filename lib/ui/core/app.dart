import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:provider/provider.dart';

/// The app, in the theme and at the level of the provided
/// [AppSettingsRepository], rebuilt at once when either changes (`RD-08`,
/// `LV-02`). Screens read the level as a [UiLevel] from above them.
class QuranApp extends StatelessWidget {
  const QuranApp({
    required this.router,
    this.themePreference = const ThemePreference(),
    super.key,
  });

  final GoRouter router;

  /// The theme while no [AppSettingsRepository] is provided.
  final ThemePreference themePreference;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsRepository?>();
    final preference = settings?.themePreference ?? themePreference;
    final level = settings?.level ?? UiLevel.initial;
    final follow = preference.followSystemDark;
    return MaterialApp.router(
      routerConfig: router,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
      // A chosen light slot may hold night or contrast: buildAppTheme sets the
      // brightness, so ThemeMode only decides whether the system is followed.
      theme: buildAppTheme(preference.theme),
      darkTheme: follow
          ? buildAppTheme(preference.resolve(systemIsDark: true))
          : null,
      themeMode: follow ? ThemeMode.system : ThemeMode.light,
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => Provider<UiLevel>.value(
        value: level,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: _systemBarsFor(
            Theme.of(context).brightness,
            ground: context.colors.ground,
          ),
          child: child!,
        ),
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
