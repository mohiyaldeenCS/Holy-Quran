import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

// .qk-player: padding 22px var(--space-5).
const double _paddingVertical = 22;
// MiniPlayer in index.jsx: `<Icon size={26} />` on the four plain buttons.
const double _iconSize = 26;
// .qk-player-main: width and height 60px; `<Icon size={28} />`.
const double _mainSize = 60;
const double _mainIconSize = 28;
// .qk-player-speed: padding 6px 12px; border-radius 12px is radius-md;
// background rgba(248, 242, 228, 0.14), paper-100 at 14%.
const double _speedPaddingVertical = 6;
const double _speedOpacity = 0.14;
// .qk-player-count: top 2px; left 2px; min-width and height 18px;
// border-radius 9px, half the height; font-size 11px.
const double _countInset = 2;
const double _countSize = 18;
const double _countFontSize = 11;

// .qk-player-title: Reem Kufi, font-size 24px, line-height 1.4, the
// surah-header style's size and line height; it sets no weight, so 400
// (D-087).
final TextStyle _titleStyle = AppTextStyles.surahHeader.copyWith(
  fontWeight: FontWeight.w400,
);
// .qk-player-sub: font-size 14px. .qk-player-speed: font-size 14px;
// font-weight 600. .qk-player-count: font-size 11px; font-weight 700. The
// body's IBM Plex Sans Arabic with its `normal` line height.
const TextStyle _subStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
final TextStyle _speedStyle = _subStyle.copyWith(fontWeight: FontWeight.w600);
final TextStyle _countStyle = _subStyle.copyWith(
  fontSize: _countFontSize,
  fontWeight: FontWeight.w700,
);

/// The emerald player card (`MiniPlayer`, `.qk-player`): the surah and ayah,
/// the reciter, the speed, a gold progress track and five buttons: repeat,
/// previous ayah, play or pause, next ayah and the sleep timer.
///
/// [surah] is the pack's surah name, drawn with [ayah] by [SurahName]. A null
/// [reciter] is hidden. [progress] runs from 0 to 1; null hides the track,
/// for a position whose length is not known. [repeat] above zero shows its
/// count on the repeat button. A button whose callback is null is disabled;
/// it keeps its place and look, as the reference draws all five and defines
/// no disabled look. Without [showSleepTimer] the sleep timer's place is left
/// empty, so the other four keep theirs.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    required this.surah,
    required this.ayah,
    required this.speed,
    required this.playing,
    this.reciter,
    this.progress = 0,
    this.repeat = 0,
    this.showSleepTimer = true,
    this.onRepeat,
    this.onPrevious,
    this.onPlayPause,
    this.onNext,
    this.onSleepTimer,
    super.key,
  }) : assert(repeat >= 0);

  final PackText surah;
  final int ayah;
  final String? reciter;
  final String speed;
  final double? progress;
  final bool playing;
  final int repeat;
  final VoidCallback? onRepeat;
  final VoidCallback? onPrevious;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onSleepTimer;
  final bool showSleepTimer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final reciter = this.reciter;
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: _paddingVertical,
        horizontal: AppSpacing.space5,
      ),
      decoration: BoxDecoration(
        color: colors.player,
        borderRadius: BorderRadius.circular(AppRadius.radiusCard),
        boxShadow: context.shadows.shadowSheet,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.space4,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SurahName(
                      surah,
                      format: SurahNameFormat.withAyah,
                      ayah: ayah,
                      style: _titleStyle.copyWith(color: colors.onPlayer),
                    ),
                    if (reciter != null)
                      Text(
                        reciter,
                        style: _subStyle.copyWith(color: colors.onPlayerMuted),
                      ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Ramps.paper100.withValues(alpha: _speedOpacity),
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: _speedPaddingVertical,
                    horizontal: AppSpacing.space3,
                  ),
                  child: Text(
                    speed,
                    style: _speedStyle.copyWith(color: colors.onPlayer),
                  ),
                ),
              ),
            ],
          ),
          if (progress case final progress?)
            ProgressBar(
              value: progress,
              tone: ProgressBarTone.player,
              label: l10n.playerPosition,
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PlayerButton(
                icon: IconName.repeat,
                label: repeat > 0
                    ? l10n.playerRepeatTimes(repeat, arabicDigits(repeat))
                    : l10n.playerRepeat,
                onPressed: onRepeat,
                count: repeat > 0 ? repeat : null,
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
                size: _mainSize,
                iconSize: _mainIconSize,
              ),
              PlayerButton(
                icon: IconName.next,
                label: l10n.playerNextAyah,
                onPressed: onNext,
              ),
              if (showSleepTimer)
                PlayerButton(
                  icon: IconName.night,
                  label: l10n.playerSleepTimer,
                  onPressed: onSleepTimer,
                )
              else
                const SizedBox.square(dimension: AppSizes.targetMin),
            ],
          ),
        ],
      ),
    );
  }
}

/// A round button on the player's emerald: plain (`.qk-player-btn`, the icon
/// in `on-player`) or main (`.qk-player-main`, the glyph in `emerald-950` on
/// `player-accent`). Shared with the reader's player bar, which draws the
/// same two kinds at its own sizes. The hit area is at least target-min.
/// Disabled when [onPressed] is null, with no change of look.
class PlayerButton extends StatelessWidget {
  const PlayerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = AppSizes.targetMin,
    this.iconSize = _iconSize,
    this.count,
    super.key,
  }) : _main = false;

  /// The gold play or pause button.
  const PlayerButton.main({
    required bool playing,
    required this.label,
    required this.onPressed,
    required this.size,
    required this.iconSize,
    super.key,
  }) : icon = playing ? IconName.pause : IconName.play,
       count = null,
       _main = true;

  final IconName icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  /// A count drawn over the top-left corner (`.qk-player-count`), such as
  /// the repeats; none when null.
  final int? count;
  final bool _main;

  static final BorderRadius _radius = BorderRadius.circular(
    AppRadius.radiusFull,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = this.count;
    final target = size < AppSizes.targetMin ? AppSizes.targetMin : size;
    final face = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _main ? colors.playerAccent : null,
        borderRadius: _radius,
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: _main ? Ramps.emerald950 : colors.onPlayer,
      ),
    );
    return Semantics(
      container: true,
      label: label,
      // Pressable covers the drawn face; this detector makes the rest of the
      // target-min square press it too, as in IconButton.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: target,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Pressable(
                onPressed: onPressed,
                focusRadius: _radius,
                child: face,
              ),
              if (count != null)
                Positioned(
                  top: _countInset,
                  left: _countInset,
                  child: ExcludeSemantics(child: _Count(count)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The count on a player button (`.qk-player-count`): a circle, or a pill
/// for a number too wide for it.
///
/// Like `AyahMarker`, its height follows the system text scale and the
/// digits are sized from it and not scaled again, so the minimum width keeps
/// up with the height at any scale.
class _Count extends StatelessWidget {
  const _Count(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.textScalerOf(context).scale(_countSize);
    return Container(
      height: side,
      constraints: BoxConstraints(minWidth: side),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.playerAccent,
        borderRadius: BorderRadius.circular(side / 2),
      ),
      child: Text(
        arabicDigits(count),
        maxLines: 1,
        softWrap: false,
        textScaler: TextScaler.noScaling,
        style: _countStyle.copyWith(
          fontSize: side * _countFontSize / _countSize,
          color: Ramps.emerald950,
        ),
      ),
    );
  }
}
