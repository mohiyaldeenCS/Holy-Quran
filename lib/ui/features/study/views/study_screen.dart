import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/route_table.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/metrics/settings_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';

/// The study tab's hub (PRD §7.1), laid out as the More hub is: the title and
/// a column of entries. Each entry opens its screen, and is shown only once
/// that screen has a route. [tafsirLocation] is where the tafsir reader
/// opens; without one the reader has no entry.
class StudyScreen extends StatelessWidget {
  const StudyScreen({required this.tafsirLocation, super.key});

  final String? tafsirLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final tafsirLocation = this.tafsirLocation;
    final entries = [
      for (final (label, location) in [
        (l10n.searchTitle, Routes.search),
        if (tafsirLocation != null) (l10n.tafsirReaderTitle, tafsirLocation),
      ])
        if (hasRoute(router, location)) (label, location),
    ];
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: SettingsMetrics.tabRootHeader,
            child: Semantics(
              header: true,
              child: Text(
                l10n.tabStudy,
                style: AppTextStyles.screenTitle.copyWith(
                  color: context.colors.ink,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: SettingsMetrics.content,
              children: [
                for (final (label, location) in entries) ...[
                  Button(
                    label: label,
                    variant: ButtonVariant.outline,
                    onPressed: () => context.go(location),
                  ),
                  const SizedBox(height: SettingsMetrics.contentGap),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
