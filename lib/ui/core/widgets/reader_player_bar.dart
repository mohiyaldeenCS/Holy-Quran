import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/core/widgets/player_surface_border.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

// The reader's floating player bar on Screens.dc.html, the paper reader with
// tajweed colours: `height: 68px; border-radius: 26px; padding: 0 14px; gap:
// 12px`.
// The height is a minimum, so the text can grow with the system text scale.
const double _minHeight = 68;
const double _radius = 26;
const double _paddingHorizontal = 14;
// The play button: `width: 48px; height: 48px`, glyph `width="22"`.
const double _mainIconSize = 22;
// The next button: `width: 44px; height: 44px`, icon `width="24"`.
const double _nextSize = 44;
// Its target-min hit area reaches this far past the drawn button on each
// side; the padding and gap beside it give the same back, so the button sits
// where the board draws it.
const double _nextBleed = (AppSizes.targetMin - _nextSize) / 2;

// The title: `font-size: 16px; font-weight: 600`. The reciter: `font-size:
// 13px`. The board's IBM Plex Sans Arabic with its `normal` line height.
const TextStyle _titleStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
final TextStyle _reciterStyle = _titleStyle.copyWith(
  fontSize: 13,
  fontWeight: FontWeight.w400,
);

/// The player bar floating at the foot of the reader (Screens board): play
/// or pause, the surah and ayah over the reciter, and the next ayah. It is
/// `player`, `player-accent` and its fixed glyph colour, so it follows the
/// theme like `MiniPlayer`; its shadow is `shadow-sheet` (D-089, 4).
///
/// [surah] is the pack's surah name, drawn with [ayah] by [SurahName]. A null
/// [reciter] is hidden. A button whose callback is null is disabled, as in
/// `MiniPlayer`.
class ReaderPlayerBar extends StatelessWidget {
  const ReaderPlayerBar({
    required this.surah,
    required this.ayah,
    required this.playing,
    this.reciter,
    this.onPlayPause,
    this.onNext,
    super.key,
  });

  final PackText surah;
  final int ayah;
  final String? reciter;
  final bool playing;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final reciter = this.reciter;
    return Container(
      constraints: const BoxConstraints(minHeight: _minHeight),
      padding: const EdgeInsetsDirectional.only(
        start: _paddingHorizontal,
        end: _paddingHorizontal - _nextBleed,
      ),
      decoration: BoxDecoration(
        color: colors.player,
        border: playerSurfaceBorder(context),
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: context.shadows.shadowSheet,
      ),
      child: Row(
        children: [
          PlayerButton.main(
            playing: playing,
            label: playing ? l10n.playerPause : l10n.playerPlay,
            onPressed: onPlayPause,
            size: AppSizes.targetMin,
            iconSize: _mainIconSize,
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                    style: _reciterStyle.copyWith(color: colors.onPlayerMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space3 - _nextBleed),
          PlayerButton(
            icon: IconName.next,
            label: l10n.playerNextAyah,
            onPressed: onNext,
            size: _nextSize,
            iconSize: AppSizes.iconSize,
          ),
        ],
      ),
    );
  }
}
