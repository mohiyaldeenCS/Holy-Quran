import 'package:flutter/material.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/home_metrics.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';

/// What a start that failed shows in place of the splash: the integrity
/// alert where home shows the base pack's (PRD §9.5, D-180). Nothing was
/// read, the user's theme included, so it is in the default `paper` theme.
class StartFailedScreen extends StatelessWidget {
  const StartFailedScreen({super.key});

  @override
  Widget build(BuildContext context) => Localizations(
    locale: const Locale('ar'),
    delegates: AppLocalizations.localizationsDelegates,
    child: Theme(data: buildAppTheme(ReadingTheme.paper), child: const _Body()),
  );
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
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
    );
  }
}
