import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/reader_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';

import 'surah_text.dart';

/// The mushaf's juz and hizb counts: the largest numbers a margin mark
/// writes, so the widest mark is among those up to them.
const int _juzCount = 30;
const int _hizbCount = 60;

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

  /// The width [mark] takes when laid out with [scaler], as [build] lays it
  /// out.
  static double widthOf(
    MarginMark mark,
    AppLocalizations strings,
    TextScaler scaler,
  ) {
    if (_starOnly(mark)) return ReaderMetrics.marginStar;
    final painter = TextPainter(
      text: TextSpan(
        text: _label(mark, strings),
        style: switch (mark.kind) {
          MarginMarkKind.sajda => _words,
          MarginMarkKind.juz => _juzName,
          MarginMarkKind.rub || MarginMarkKind.hizb => _starWords,
        },
      ),
      textDirection: TextDirection.rtl,
      textScaler: scaler,
    )..layout();
    final words = painter.width;
    painter.dispose();
    return switch (mark.kind) {
      MarginMarkKind.sajda || MarginMarkKind.juz => words,
      MarginMarkKind.rub || MarginMarkKind.hizb =>
        ReaderMetrics.marginStar + ReaderMetrics.marginStarGap + words,
    };
  }

  /// The width of the widest mark the reader can show, at [scaler]: every
  /// juz, every hizb and its first quarter, a later quarter's star and the
  /// sajda (D-181).
  static double widest(AppLocalizations strings, TextScaler scaler) {
    final marks = [
      const MarginMark(MarginMarkKind.sajda, 1),
      const MarginMark(MarginMarkKind.rub, 1, hizb: 1, quarter: 2),
      for (var juz = 1; juz <= _juzCount; juz++)
        MarginMark(MarginMarkKind.juz, 1, juz: juz),
      for (var hizb = 1; hizb <= _hizbCount; hizb++) ...[
        MarginMark(MarginMarkKind.hizb, 1, hizb: hizb),
        MarginMark(MarginMarkKind.rub, 1, hizb: hizb, quarter: 1),
      ],
    ];
    var widest = 0.0;
    for (final mark in marks) {
      final width = widthOf(mark, strings, scaler);
      if (width > widest) widest = width;
    }
    return widest;
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
