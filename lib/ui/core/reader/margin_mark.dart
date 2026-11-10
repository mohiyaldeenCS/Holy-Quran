import 'dart:math' as math;

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
/// sajda, whose sign is in the text itself. Where it stands is the reader
/// screen's: in a row above the line its ayah begins in (D-181).
final class MarginMarkView extends StatelessWidget {
  const MarginMarkView(this.mark, {super.key});

  final MarginMark mark;

  static final TextStyle _words = AppTextStyles.secondary.copyWith(
    fontSize: ReaderMetrics.marginLabelSize,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle _starWords = _words.copyWith(
    height: ReaderMetrics.marginLabelHeight,
  );

  static final TextStyle _juzName = AppTextStyles.surahHeader.copyWith(
    fontSize: ReaderMetrics.juzNameSize,
  );

  static String _label(MarginMark mark, AppLocalizations strings) =>
      switch (mark.kind) {
        MarginMarkKind.sajda => strings.sajdaLabel,
        MarginMarkKind.juz => strings.juzLabel(arabicDigits(mark.juz!)),
        MarginMarkKind.rub when mark.quarter == 1 =>
          '${strings.rubLabel}\n${strings.hizbLabel(arabicDigits(mark.hizb!))}',
        MarginMarkKind.rub ||
        MarginMarkKind.hizb => strings.hizbLabel(arabicDigits(mark.hizb!)),
      };

  static bool _starOnly(MarginMark mark) =>
      mark.kind == MarginMarkKind.rub && mark.quarter != 1;

  /// The size [mark] takes when laid out with [scaler], as [build] lays it
  /// out; [bold] when the system asks for bold text, which `Text` follows.
  static Size sizeOf(
    MarginMark mark,
    AppLocalizations strings,
    TextScaler scaler, {
    bool bold = false,
  }) {
    if (_starOnly(mark)) {
      return const Size.square(ReaderMetrics.marginStar);
    }
    final style = switch (mark.kind) {
      MarginMarkKind.sajda => _words,
      MarginMarkKind.juz => _juzName,
      MarginMarkKind.rub || MarginMarkKind.hizb => _starWords,
    };
    final painter = TextPainter(
      text: TextSpan(
        text: _label(mark, strings),
        style: bold
            ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
            : style,
      ),
      textDirection: TextDirection.rtl,
      textScaler: scaler,
    )..layout();
    final words = painter.size;
    painter.dispose();
    return switch (mark.kind) {
      MarginMarkKind.sajda => words,
      MarginMarkKind.juz => Size(
        words.width,
        words.height + ReaderMetrics.juzRuleGap + ReaderMetrics.juzRule,
      ),
      MarginMarkKind.rub || MarginMarkKind.hizb => Size(
        ReaderMetrics.marginStar + ReaderMetrics.marginStarGap + words.width,
        math.max(ReaderMetrics.marginStar, words.height),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = context.colors;
    final label = _label(mark, strings);
    switch (mark.kind) {
      case MarginMarkKind.sajda:
        return Text(label, style: _words.copyWith(color: colors.accent));
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
          child: Text(label, style: _juzName.copyWith(color: colors.primary)),
        );
      case MarginMarkKind.rub || MarginMarkKind.hizb:
        if (_starOnly(mark)) {
          return const StarOutline(size: ReaderMetrics.marginStar);
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: ReaderMetrics.marginStarGap,
          children: [
            const StarOutline(size: ReaderMetrics.marginStar),
            Text(label, style: _starWords.copyWith(color: colors.accent)),
          ],
        );
    }
  }
}
