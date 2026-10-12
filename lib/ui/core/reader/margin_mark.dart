import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/reader_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';

import 'surah_text.dart';

/// A surah-mode margin mark (`RD-02`, `RD-15`), as the Mushaf board draws it:
/// the quarter star with «ربع» and «الحزب n» at a rub, the star with
/// «الحزب n» at a hizb and «الجزء n» at a juz, and the word «سجدة» alone at a
/// sajda, whose sign is in the text itself. Where it stands beside its line
/// is the reader screen's.
final class MarginMarkView extends StatelessWidget {
  const MarginMarkView(this.mark, {super.key});

  final MarginMark mark;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final style = AppTextStyles.secondary.copyWith(
      fontSize: ReaderMetrics.marginLabelSize,
      height: ReaderMetrics.marginLabelHeight,
      fontWeight: FontWeight.w600,
      color: context.colors.accent,
    );
    final lines = switch (mark.kind) {
      MarginMarkKind.rub => [
        strings.rubLabel,
        strings.hizbLabel(arabicDigits(mark.hizb!)),
      ],
      MarginMarkKind.hizb => [strings.hizbLabel(arabicDigits(mark.hizb!))],
      MarginMarkKind.juz => [strings.juzLabel(arabicDigits(mark.juz!))],
      MarginMarkKind.sajda => [strings.sajdaLabel],
    };
    final words = Text(lines.join('\n'), style: style);
    if (mark.kind == MarginMarkKind.sajda) return words;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: ReaderMetrics.marginStarGap,
      children: [
        const StarOutline(size: ReaderMetrics.marginStar),
        words,
      ],
    );
  }
}
