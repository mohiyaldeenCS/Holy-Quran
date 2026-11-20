import 'package:flutter/material.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/home_metrics.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/system_bars.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';

/// What a start that failed shows in place of the splash: the integrity
/// alert where home shows the base pack's (PRD §9.5, D-180), in [theme] as
/// the app would show it, following a dark system when [theme] says so.
class StartFailedScreen extends StatelessWidget {
  const StartFailedScreen({required this.theme, super.key});

  final ThemePreference theme;

  @override
  Widget build(BuildContext context) {
    final systemIsDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Localizations(
      locale: const Locale('ar'),
      delegates: AppLocalizations.localizationsDelegates,
      child: Theme(
        data: buildAppTheme(theme.resolve(systemIsDark: systemIsDark)),
        child: const _Body(),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SystemBars(
      child: ColoredBox(
        color: context.colors.ground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: HomeMetrics.bodyPadding,
            child: IntegrityAlert(
              title: l10n.integrityStartFailedTitle,
              body: l10n.integrityStartFailedBody,
            ),
          ),
        ),
      ),
    );
  }
}
