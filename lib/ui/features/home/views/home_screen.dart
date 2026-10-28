import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/route_table.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/home_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/continue_card.dart';
import 'package:holyquran/ui/core/widgets/continue_listening_row.dart';
import 'package:holyquran/ui/core/widgets/home_door.dart';
import 'package:holyquran/ui/core/widgets/home_header.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/features/home/view_models/home_view_model.dart';

/// The home screen as the Screens board draws it, without its Phase 2
/// parts (PRD §7.1, §12.3): the header, the greeting, «أكمل القراءة»,
/// «أكمل الاستماع» and the doors of the features that have shipped. While the
/// base pack fails its check it shows the integrity alert in place of the
/// greeting and the rows (PRD §9.5).
class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.viewModel, super.key});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final doors = [
      HomeDoor(
        icon: IconName.indexIcon,
        label: l10n.homeDoorIndex,
        onPressed: () => context.go(Routes.mushafIndex),
      ),
      if (hasRoute(router, Routes.bookmarks))
        HomeDoor(
          icon: IconName.bookmark,
          label: l10n.homeDoorBookmarks,
          onPressed: () => context.go(Routes.bookmarks),
        ),
    ];
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: HomeMetrics.headerPadding,
            child: HomeHeader(onSearch: () => context.go(Routes.search)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: HomeMetrics.bodyPadding,
              child: ListenableBuilder(
                listenable: viewModel,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: HomeMetrics.sectionGap,
                  children: [
                    if (viewModel.baseFailed)
                      IntegrityAlert(
                        title: l10n.integrityBaseTitle,
                        body: l10n.integrityBaseBody,
                      )
                    else ...[
                      const _Greeting(),
                      if (viewModel.continueReading case final reading?)
                        _ContinueReadingCard(reading),
                      if (viewModel.continueListening case final listening?)
                        ContinueListeningRow(
                          surahName: listening.surahName,
                          ayah: listening.ayah,
                          reciter: listening.reciter,
                          onPlay: viewModel.resumeListening,
                        ),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: AppSpacing.space2,
                      children: [
                        for (var i = 0; i < HomeMetrics.doorColumns; i++)
                          Expanded(
                            child: i < doors.length
                                ? doors[i]
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    return Padding(
      padding: HomeMetrics.greetingPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.homeGreeting,
            style: HomeMetrics.greetingStyle.copyWith(color: colors.inkMuted),
          ),
          Semantics(
            header: true,
            child: Text(
              l10n.homeContinueHint,
              style: AppTextStyles.screenTitle.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard(this.reading);

  final ContinueReading reading;

  @override
  Widget build(BuildContext context) => ContinueCard(
    surah: reading.surahName,
    meta: AppLocalizations.of(context).readingPositionLine(
      arabicDigits(reading.address.ayah),
      arabicDigits(reading.page),
      arabicDigits(reading.juz),
    ),
    progress: reading.progress,
    onContinue: () => context.go(Routes.mushafRead(reading.address)),
  );
}
