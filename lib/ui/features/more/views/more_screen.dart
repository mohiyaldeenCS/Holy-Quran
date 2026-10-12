import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/metrics/settings_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';

/// The More tab's hub (PRD §7.1), an extension under the index screen's
/// header, its entries in the settings screen's column. Each entry opens its
/// screen; one not built yet lands on the home tab, as every unknown
/// location does.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = [
      (l10n.bookmarksAndNotes, Routes.bookmarks),
      (l10n.resourceManagerTitle, Routes.resources),
      (l10n.settingsTitle, Routes.settings),
      (l10n.sourcesTitle, Routes.sources),
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
                l10n.tabMore,
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
                // The gallery is a review tool, not part of the product.
                if (kDebugMode)
                  Button(
                    label: l10n.galleryTitle,
                    variant: ButtonVariant.text,
                    onPressed: () => context.push(Routes.gallery),
                  ),
                const SizedBox(height: AppSpacing.space5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
