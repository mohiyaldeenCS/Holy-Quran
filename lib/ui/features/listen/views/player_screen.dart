import 'package:flutter/widgets.dart' hide Icon;
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/player_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';
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
                  IconButton(
                    icon: IconName.indexIcon,
                    label: l10n.queueLabel,
                    tone: IconButtonTone.tint,
                    onPressed: () => context.push(Routes.queueSheet),
                  ),
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
      onSleepTimer: () => context.push(Routes.sleepSheet),
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

/// The emerald card at the foot of the Screens2 listen screen: the gold
/// track, which seeks when [progress] is known, the position line, five
/// buttons (sleep timer, previous ayah, play or pause, next ayah, repeat)
/// and a row of chips: the range, the repeat, the speed and the silence.
/// A null label hides its line or chip.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({
    required this.playing,
    required this.speed,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onSpeed,
    required this.onSleepTimer,
    required this.onRepeat,
    required this.onRange,
    required this.onSilence,
    this.progress,
    this.onSeek,
    this.onSeekBy,
    this.position,
    this.repeat,
    this.range,
    this.repeatLabel,
    this.silence,
    super.key,
  });

  final bool playing;

  /// From 0 to 1; null hides the track.
  final double? progress;
  final ValueChanged<double>? onSeek;
  final ValueChanged<Duration>? onSeekBy;
  final String? position;
  final String speed;

  /// The repeat count drawn on the repeat button.
  final int? repeat;
  final String? range;
  final String? repeatLabel;
  final String? silence;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSpeed;
  final VoidCallback onSleepTimer;
  final VoidCallback onRepeat;
  final VoidCallback onRange;
  final VoidCallback onSilence;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final progress = this.progress;
    final position = this.position;
    final repeat = this.repeat;
    final range = this.range;
    final repeatLabel = this.repeatLabel;
    final silence = this.silence;
    return Container(
      width: double.infinity,
      padding: PlayerMetrics.panelPadding,
      decoration: BoxDecoration(
        color: colors.player,
        borderRadius: PlayerMetrics.panelRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PlayerMetrics.panelGap,
        children: [
          if (progress != null || position != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: PlayerMetrics.trackGap,
              children: [
                if (progress != null)
                  _SeekTrack(
                    progress: progress,
                    onSeek: onSeek,
                    onSeekBy: onSeekBy,
                  ),
                if (position != null)
                  Text(
                    position,
                    textAlign: TextAlign.end,
                    style: PlayerMetrics.smallText.copyWith(
                      color: colors.onPlayerMuted,
                    ),
                  ),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PlayerButton(
                icon: IconName.night,
                label: l10n.playerSleepTimer,
                onPressed: onSleepTimer,
              ),
              PlayerButton(
                icon: IconName.previous,
                label: l10n.playerPreviousAyah,
                onPressed: onPrevious,
              ),
              PlayerButton.main(
                playing: playing,
                label: playing ? l10n.playerPause : l10n.playerPlay,
                onPressed: onPlayPause,
                size: PlayerMetrics.mainButtonSize,
                iconSize: PlayerMetrics.mainIconSize,
              ),
              PlayerButton(
                icon: IconName.next,
                label: l10n.playerNextAyah,
                onPressed: onNext,
              ),
              // The board tints the repeat button while a repeat is set.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: repeat == null
                      ? null
                      : colors.onPlayer.withValues(
                          alpha: PlayerMetrics.tintOpacity,
                        ),
                  shape: BoxShape.circle,
                ),
                child: PlayerButton(
                  icon: IconName.repeat,
                  label: repeat == null
                      ? l10n.playerRepeat
                      : l10n.playerRepeatTimes(repeat, arabicDigits(repeat)),
                  onPressed: onRepeat,
                  count: repeat,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: [
              if (range != null)
                _PanelChip(label: range, onPressed: onRange, active: true),
              if (repeatLabel != null)
                _PanelChip(label: repeatLabel, onPressed: onRepeat),
              _PanelChip(label: speed, onPressed: onSpeed),
              if (silence != null)
                _PanelChip(label: silence, onPressed: onSilence),
            ],
          ),
        ],
      ),
    );
  }
}

/// The player-tone [ProgressBar] in a target-min band that seeks where it
/// is tapped or dragged, from the right in Arabic; a screen reader moves it
/// by [PlayerMetrics.seekStep].
class _SeekTrack extends StatefulWidget {
  const _SeekTrack({required this.progress, this.onSeek, this.onSeekBy});

  final double progress;
  final ValueChanged<double>? onSeek;
  final ValueChanged<Duration>? onSeekBy;

  @override
  State<_SeekTrack> createState() => _SeekTrackState();
}

class _SeekTrackState extends State<_SeekTrack> {
  /// Where a drag holds the track; it seeks once, on release.
  double? _dragged;

  double? _fractionAt(double dx) {
    final width = context.size?.width ?? 0;
    if (width <= 0) return null;
    final fraction = (dx / width).clamp(0.0, 1.0);
    return Directionality.of(context) == TextDirection.rtl
        ? 1 - fraction
        : fraction;
  }

  void _drag(DragUpdateDetails details) =>
      setState(() => _dragged = _fractionAt(details.localPosition.dx));

  void _release(ValueChanged<double> onSeek) {
    final dragged = _dragged;
    setState(() => _dragged = null);
    if (dragged != null) onSeek(dragged);
  }

  @override
  Widget build(BuildContext context) {
    final onSeek = widget.onSeek;
    final onSeekBy = widget.onSeekBy;
    return MergeSemantics(
      child: Semantics(
        onIncrease: onSeekBy == null
            ? null
            : () => onSeekBy(PlayerMetrics.seekStep),
        onDecrease: onSeekBy == null
            ? null
            : () => onSeekBy(-PlayerMetrics.seekStep),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapUp: onSeek == null
              ? null
              : (details) {
                  if (_fractionAt(details.localPosition.dx) case final at?) {
                    onSeek(at);
                  }
                },
          onHorizontalDragUpdate: onSeek == null ? null : _drag,
          onHorizontalDragEnd: onSeek == null ? null : (_) => _release(onSeek),
          onHorizontalDragCancel: () => setState(() => _dragged = null),
          child: SizedBox(
            height: AppSizes.targetMin,
            child: Center(
              child: ProgressBar(
                value: _dragged ?? widget.progress,
                tone: ProgressBarTone.player,
                label: AppLocalizations.of(context).playerPosition,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A chip of the panel: [active] is the board's paper chip, the others its
/// tinted chips. Drawn 36 high in a target-min hit area; it grows with the
/// text.
class _PanelChip extends StatelessWidget {
  const _PanelChip({
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = active
        ? (colors.onPlayer, colors.player)
        : (
            colors.onPlayer.withValues(alpha: PlayerMetrics.tintOpacity),
            colors.onPlayer,
          );
    return Semantics(
      container: true,
      label: label,
      // Pressable covers the drawn chip; this detector makes the bands above
      // and below it, up to target-min, press it too, as in IconButton.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Pressable(
              onPressed: onPressed,
              focusRadius: PlayerMetrics.chipRadius,
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: PlayerMetrics.chipRadius,
                  ),
                  child: Padding(
                    padding: PlayerMetrics.chipPadding,
                    // A row in a minimum height centres the label and keeps
                    // the chip as wide as its text.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: PlayerMetrics.chipHeight,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: PlayerMetrics.chipText.copyWith(
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The reciter card of the Screens2 board's listen screen: the star badge,
/// the reciter over a line of details, and «تغيير» when [onChange] is
/// given. A null [reciter] or [details] is hidden, the badge with the
/// reciter.
class RecitationCard extends StatelessWidget {
  const RecitationCard({this.reciter, this.details, this.onChange, super.key});

  final String? reciter;
  final String? details;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reciter = this.reciter;
    final details = this.details;
    final onChange = this.onChange;
    return Container(
      padding: PlayerMetrics.reciterCardPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: PlayerMetrics.reciterCardRadius,
      ),
      child: Row(
        spacing: AppSpacing.space3,
        children: [
          if (reciter != null)
            Container(
              width: AppSizes.targetMin,
              height: AppSizes.targetMin,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.player,
                shape: BoxShape.circle,
              ),
              child: StarOutline(
                size: PlayerMetrics.reciterStarSize,
                color: colors.playerAccent,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reciter != null)
                  Text(
                    reciter,
                    style: AppTextStyles.bodyStrong.copyWith(color: colors.ink),
                  ),
                if (details != null && details.isNotEmpty)
                  Text(
                    details,
                    style: PlayerMetrics.smallText.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (onChange != null) _ChangeButton(onPressed: onChange),
        ],
      ),
    );
  }
}

/// «تغيير», a text action with a target-min hit area.
class _ChangeButton extends StatelessWidget {
  const _ChangeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).playerChange;
    return Semantics(
      container: true,
      label: label,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: PlayerMetrics.changeFocusRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSizes.targetMin,
            minHeight: AppSizes.targetMin,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: ExcludeSemantics(
              child: Text(
                label,
                style: PlayerMetrics.changeText.copyWith(
                  color: context.colors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
