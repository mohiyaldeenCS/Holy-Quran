import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

// Mushaf.dc.html, «تشريح الصفحة»: the surah's name in Reem Kufi,
// `font-size: 20px; font-weight: 600; color` primary. No line height is set,
// so it is the font's own (CSS `normal`), as a style with no height draws it;
// the styles do not inherit, so the ambient body line height cannot reach it.
const TextStyle _nameStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.kufi,
  fontFamilyFallback: [AppFonts.sans],
  fontSize: 20,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

// Mushaf.dc.html, «تشريح الصفحة»: the juz and hizb line, `font-size: 13px;
// color` ink-muted, in the body's IBM Plex Sans Arabic 400.
const TextStyle _lineStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The position bar (`RD-05`) as the Mushaf board draws it: the name of the
/// surah the first visible ayah is in, in Reem Kufi, at one end, and its
/// juz and hizb at the other. The reference page number stands in the
/// reader's footer, as both boards draw it. It has no padding of its own.
///
/// [surahName] is the pack's name without the word for surah, drawn by
/// [SurahName].
final class PositionBar extends StatelessWidget {
  const PositionBar({
    required this.surahName,
    required this.juz,
    required this.hizb,
    super.key,
  });

  final PackText surahName;
  final int juz;
  final int hizb;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: AppSpacing.space3,
      children: [
        Flexible(
          child: SurahName(
            surahName,
            style: _nameStyle.copyWith(color: colors.primary),
          ),
        ),
        Text(
          AppLocalizations.of(
            context,
          ).juzHizbLine(arabicDigits(juz), arabicDigits(hizb)),
          style: _lineStyle.copyWith(color: colors.inkMuted),
        ),
      ],
    );
  }
}
