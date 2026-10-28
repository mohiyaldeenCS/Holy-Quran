import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/player_surface_border.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

// .qk-continue: border-radius 26px; gap 10px.
const double _radius = 26;
const double _gap = 10;
// .qk-continue-stars: left -50px; top -50px; width and height 200; stroke
// width 0.8 in the 120 viewBox; color gold-400; opacity 0.28.
const double _starsOffset = -50;
const double _starsSize = 200;
const double _starsStroke = 0.8;
const double _starsOpacity = 0.28;

// .qk-continue-label: font-size 13px; font-weight 600. .qk-continue-meta:
// font-size 15px. .qk-continue-btn: font-size 16px; font-weight 600. The
// body's IBM Plex Sans Arabic with its `normal` line height.
const TextStyle _labelStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
final TextStyle _metaStyle = _labelStyle.copyWith(
  fontSize: 15,
  fontWeight: FontWeight.w400,
);
final TextStyle _actionStyle = _labelStyle.copyWith(fontSize: 16);
// .qk-continue-title: Reem Kufi, font-size 32px, line-height 1.3, the
// surah-card style's size and line height; it sets no weight, so 400 (D-087).
final TextStyle _titleStyle = AppTextStyles.surahCard.copyWith(
  fontWeight: FontWeight.w400,
);

/// The «أكمل القراءة» card of the home screen (`ContinueCard`,
/// `.qk-continue`): emerald, a faint gold quarter star in the corner, the
/// surah name, the position, the progress through the mushaf and the
/// continue button.
///
/// [surah] is the pack's surah name, drawn by [SurahName] after the word for
/// surah. A null [meta] is hidden. [progress] runs from 0 to 1. The label is
/// `player-accent` on `player`, as the reference draws it (O-12).
class ContinueCard extends StatelessWidget {
  const ContinueCard({
    required this.surah,
    required this.onContinue,
    this.meta,
    this.progress = 0,
    super.key,
  });

  final PackText surah;
  final String? meta;
  final double progress;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final meta = this.meta;
    final radius = BorderRadius.circular(_radius);
    final card = ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: colors.player,
        child: Stack(
          children: [
            const Positioned(
              left: _starsOffset,
              top: _starsOffset,
              child: Opacity(
                opacity: _starsOpacity,
                child: StarOutline(
                  size: _starsSize,
                  stroke: _starsStroke,
                  color: Ramps.gold400,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: _gap,
                children: [
                  Text(
                    l10n.continueReadingLabel,
                    style: _labelStyle.copyWith(color: colors.playerAccent),
                  ),
                  SurahName(
                    surah,
                    format: SurahNameFormat.titled,
                    style: _titleStyle.copyWith(color: colors.onPlayer),
                  ),
                  if (meta != null)
                    Text(
                      meta,
                      style: _metaStyle.copyWith(color: colors.onPlayerMuted),
                    ),
                  ProgressBar(
                    value: progress,
                    tone: ProgressBarTone.player,
                    label: l10n.continueReadingPosition,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _ContinueButton(
                      label: l10n.continueReadingAction,
                      onPressed: onContinue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final border = playerSurfaceBorder(context);
    if (border == null) return card;
    // Drawn over the clipped card, so the border is not clipped with it.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(border: border, borderRadius: radius),
      child: card,
    );
  }
}

/// `.qk-continue-btn`: `on-player` with `player` text, 48 high, radius 16,
/// padded 24 on each side, at the start of the line.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static final BorderRadius _buttonRadius = BorderRadius.circular(
    AppRadius.radiusButton,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: label,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: _buttonRadius,
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.targetMin,
              minWidth: AppSizes.targetMin,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space5),
            decoration: BoxDecoration(
              color: colors.onPlayer,
              borderRadius: _buttonRadius,
            ),
            // Centred in the minimum size without stretching to the line.
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: _actionStyle.copyWith(color: colors.player),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
