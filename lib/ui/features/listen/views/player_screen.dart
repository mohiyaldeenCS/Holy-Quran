import 'package:flutter/widgets.dart' hide Icon;
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/route_table.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/player_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/player_panel.dart';
import 'package:holyquran/ui/core/widgets/recitation_card.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/features/listen/view_models/player_view_model.dart';

/// The full player (`AU-05`, `AU-06`), the listen screen of the Screens2
/// board: the header with the queue, the reciter card with «تغيير», the
/// surah and ayah heard, and the emerald [PlayerPanel]. With no
/// [viewModel], or nothing played yet, only the header and «تغيير» remain.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({required this.viewModel, super.key});

  final PlayerViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final viewModel = this.viewModel;
    if (viewModel == null) return _layout(context, null);
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => _layout(context, viewModel),
    );
  }

  Widget _layout(BuildContext context, PlayerViewModel? player) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final surah = player?.surah;
    final ayah = player?.ayah;
    final page = player?.page;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: PlayerMetrics.headerPadding,
              child: Row(
                spacing: AppSpacing.space2,
                children: [
                  const SizedBox.square(dimension: AppSizes.targetMin),
                  Expanded(
                    child: Text(
                      l10n.tabListen,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: colors.ink,
                      ),
                    ),
                  ),
                  // The queue is the player's: with none, its sheet has nothing
                  // to open over.
                  if (player != null)
                    IconButton(
                      icon: IconName.indexIcon,
                      label: l10n.queueLabel,
                      tone: IconButtonTone.tint,
                      onPressed: () => context.push(Routes.queueSheet),
                    )
                  else
                    const SizedBox.square(dimension: AppSizes.targetMin),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: PlayerMetrics.bodyPadding,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.space3,
                children: [
                  RecitationCard(
                    reciter: player?.reciter,
                    details: player?.style,
                    onChange: () => context.go(Routes.recitations),
                  ),
                  if (surah != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      spacing: AppSpacing.space2,
                      children: [
                        Flexible(
                          child: SurahName(
                            surah.name,
                            format: ayah == null
                                ? SurahNameFormat.name
                                : SurahNameFormat.withAyah,
                            ayah: ayah,
                            style: AppTextStyles.surahHeader.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                        if (page != null)
                          Text(
                            l10n.pageLabel(arabicDigits(page)),
                            style: PlayerMetrics.smallText.copyWith(
                              color: colors.inkMuted,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (player != null && player.hasPlan)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _panelOf(context, player),
              ),
            ),
        ],
      ),
    );
  }

  Widget _panelOf(BuildContext context, PlayerViewModel player) {
    final l10n = AppLocalizations.of(context);
    final ayah = player.ayah;
    final total = player.surah?.ayahCount;
    final repeat = player.repeatCount;
    final silence = player.silenceSeconds;
    final rangeEnd = player.rangeEnd;
    return PlayerPanel(
      playing: player.playing,
      progress: player.progress,
      onSeek: player.seekTo,
      onSeekBy: player.seekBy,
      position: ayah != null && total != null
          ? l10n.playerAyahOfTotal(arabicDigits(ayah), arabicDigits(total))
          : null,
      speed: playerSpeedLabel(player.speed),
      repeat: repeat,
      range: rangeEnd == null ? null : _rangeLabel(l10n, rangeEnd),
      repeatLabel: repeat == null
          ? null
          : l10n.playerRepeatTimes(repeat, arabicDigits(repeat)),
      silence: silence == null
          ? null
          : l10n.playerSilenceSeconds(arabicDigits(silence)),
      onPlayPause: player.playPause,
      onPrevious: player.previousAyah,
      onNext: player.nextAyah,
      onSpeed: player.nextSpeed,
      // AU-07 adds the sheet; until its route exists the button is not shown.
      onSleepTimer: hasRoute(GoRouter.of(context), Routes.sleepSheet)
          ? () => context.push(Routes.sleepSheet)
          : null,
      onRepeat: () => context.push(Routes.repeatSheet),
      onRange: () => context.push(Routes.rangeSheet),
      onSilence: () => context.push(Routes.silenceSheet),
    );
  }
}

String _rangeLabel(AppLocalizations l10n, AyahToolEnd end) => switch (end) {
  AyahToolEnd.ayah => l10n.playOnlyAyah,
  AyahToolEnd.page => l10n.playToPageEnd,
  AyahToolEnd.surah => l10n.playToSurahEnd,
  AyahToolEnd.juz => l10n.playToJuzEnd,
  AyahToolEnd.untilStopped => l10n.playUntilStopped,
};
