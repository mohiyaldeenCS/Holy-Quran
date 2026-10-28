import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/route_table.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/metrics/search_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';

/// The study tab's hub (PRD §7.1), laid out as the More hub is: the title and
/// a column of entries. Each entry opens its screen, and is shown only once
/// that screen has a route. [tafsirAddress] is where the tafsir reader opens;
/// without one the reader has no entry.
class StudyScreen extends StatelessWidget {
  const StudyScreen({required this.tafsirAddress, super.key});

  final QuranAddress? tafsirAddress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final tafsirAddress = this.tafsirAddress;
    final entries = [
      for (final (label, location) in [
        (l10n.searchTitle, Routes.search),
        if (tafsirAddress != null)
          (l10n.tafsirReaderTitle, Routes.studyTafsir(tafsirAddress)),
      ])
        if (hasRoute(router, location)) (label, location),
    ];
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: SearchMetrics.hubHeader,
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
              padding: SearchMetrics.hubContent,
              children: [
                for (final (label, location) in entries) ...[
                  Button(
                    label: label,
                    variant: ButtonVariant.outline,
                    onPressed: () => context.go(location),
                  ),
                  const SizedBox(height: SearchMetrics.hubGap),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
