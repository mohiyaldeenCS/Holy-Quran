import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/reader_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';

import 'surah_text.dart';

/// A surah-mode margin mark (`RD-02`, `RD-15`), as the Mushaf board draws
/// it: the quarter star with «الحزب n» at a hizb and with «ربع» above it at
/// the hizb's first quarter, the one quarter the identity names; the half
/// and the three quarters have no words yet (D-115), so their star stands
/// alone rather than repeat the hizb's start. The juz's
/// name in Kufi over a gold line at a juz, and the word «سجدة» alone at a
/// sajda, whose sign is in the text itself. Where it stands beside its line
/// is the reader screen's.
final class MarginMarkView extends StatelessWidget {
  const MarginMarkView(this.mark, {super.key});

  final MarginMark mark;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = context.colors;
    final words = AppTextStyles.secondary.copyWith(
      fontSize: ReaderMetrics.marginLabelSize,
      fontWeight: FontWeight.w600,
      color: colors.accent,
    );
    switch (mark.kind) {
      case MarginMarkKind.sajda:
        return Text(strings.sajdaLabel, style: words);
      case MarginMarkKind.juz:
        return Container(
          padding: const EdgeInsets.only(bottom: ReaderMetrics.juzRuleGap),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.ornament,
                width: ReaderMetrics.juzRule,
              ),
            ),
          ),
          child: Text(
            strings.juzLabel(arabicDigits(mark.juz!)),
            style: AppTextStyles.surahHeader.copyWith(
              fontSize: ReaderMetrics.juzNameSize,
              color: colors.primary,
            ),
          ),
        );
      case MarginMarkKind.rub when mark.quarter != 1:
        return const StarOutline(size: ReaderMetrics.marginStar);
      case MarginMarkKind.rub || MarginMarkKind.hizb:
        final hizb = strings.hizbLabel(arabicDigits(mark.hizb!));
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: ReaderMetrics.marginStarGap,
          children: [
            const StarOutline(size: ReaderMetrics.marginStar),
            Text(
              mark.kind == MarginMarkKind.rub
                  ? '${strings.rubLabel}\n$hizb'
                  : hizb,
              style: words.copyWith(height: ReaderMetrics.marginLabelHeight),
            ),
          ],
        );
    }
  }
}
