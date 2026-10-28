import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/player_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/core/widgets/player_panel_chip.dart';
import 'package:holyquran/ui/core/widgets/seek_track.dart';

/// The emerald card at the foot of the Screens2 listen screen: the gold
/// track, which seeks when [progress] is known, the position line, five
/// buttons (sleep timer, previous ayah, play or pause, next ayah, repeat)
/// and a row of chips: the range, the repeat, the speed and the silence. The
/// range and silence chips are the only way to their sheets, so they always
/// show. A null label hides the position line or the repeat chip; a null [onSleepTimer] hides the sleep
/// timer, leaving its place empty so the other buttons keep theirs.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({
    required this.playing,
    required this.speed,
    required this.range,
    required this.silence,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onSpeed,
    required this.onRepeat,
    required this.onRange,
    required this.onSilence,
    this.progress,
    this.onSeek,
    this.onSeekBy,
    this.onSleepTimer,
    this.position,
    this.repeat,
    this.repeatLabel,
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
  final String range;
  final String? repeatLabel;
  final String silence;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSpeed;
  final VoidCallback? onSleepTimer;
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
    final repeatLabel = this.repeatLabel;
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
                  SeekTrack(
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
              if (onSleepTimer case final onSleepTimer?)
                PlayerButton(
                  icon: IconName.night,
                  label: l10n.playerSleepTimer,
                  onPressed: onSleepTimer,
                )
              else
                const SizedBox.square(dimension: AppSizes.targetMin),
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
                  accented: repeat != null,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.space2,
            runSpacing: AppSpacing.space2,
            children: [
              PlayerPanelChip(label: range, onPressed: onRange, active: true),
              if (repeatLabel != null)
                PlayerPanelChip(label: repeatLabel, onPressed: onRepeat),
              PlayerPanelChip(label: speed, onPressed: onSpeed),
              PlayerPanelChip(label: silence, onPressed: onSilence),
            ],
          ),
        ],
      ),
    );
  }
}
