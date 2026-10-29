import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

/// The home screen's «أكمل الاستماع» row (Screens.dc.html, the home board):
/// the surah and ayah where listening stopped, the [reciter] under them when
/// known, and a play button. A listening position that cannot name an ayah,
/// as in a whole-surah recording, has a null [ayah] and names the surah only.
final class ContinueListeningRow extends StatelessWidget {
  const ContinueListeningRow({
    required this.surahName,
    required this.onPlay,
    this.ayah,
    this.reciter,
    super.key,
  });

  /// The pack's surah name, written «سورة name · الآية n» as the board does,
  /// or «سورة name» without an [ayah].
  final PackText surahName;
  final int? ayah;
  final String? reciter;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final reciter = this.reciter;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _paddingX,
        vertical: _paddingY,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Row(
        // A reading: the board's row (Screens.dc.html l.41) is
        // `justify-content:space-between` with no gap; without one a long
        // title runs up to the play button, at 100% and at 200%.
        spacing: AppSpacing.space3,
        children: [
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.continueListeningLabel,
                    style: AppTextStyles.caption.copyWith(color: colors.accent),
                  ),
                  SurahName(
                    surahName,
                    format: ayah == null
                        ? SurahNameFormat.titled
                        : SurahNameFormat.titledWithAyah,
                    ayah: ayah,
                    style: _titleStyle.copyWith(color: colors.ink),
                  ),
                  if (reciter != null)
                    Text(
                      reciter,
                      style: _reciterStyle.copyWith(color: colors.inkMuted),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: IconName.play,
            label: l10n.playerPlay,
            tone: IconButtonTone.solid,
            size: AppSizes.buttonHeight,
            onPressed: onPlay,
          ),
        ],
      ),
    );
  }
}

// Screens.dc.html, «أكمل الاستماع» row: `border-radius:22px;background:#FFFBF2;
// border:1px solid #DDD2B8;padding:14px 18px` (surface, line). The 1px border
// is Border.all's default width.
const double _radius = 22;
const double _paddingX = 18;
const double _paddingY = 14;

// Screens.dc.html, «أكمل الاستماع» row: the title is
// `font-size:17px;font-weight:600;line-height:1.5`, body-strong at line
// height 1.5 rather than 1.6.
final TextStyle _titleStyle = AppTextStyles.bodyStrong.copyWith(height: 1.5);

// Screens.dc.html, «أكمل الاستماع» row: the reciter is `font-size:13px;
// color:#51605D` (ink-muted) in the body's IBM Plex Sans Arabic 400, with no
// line height set: the font's own, as a TextStyle with no height draws it.
const TextStyle _reciterStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
