import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The sizes of Quran text (`.qk-quran-*`).
enum QuranTextSize {
  /// Mushaf page and surah mode.
  page,

  /// Ayah row, study, the ayah in the player.
  ayah,

  /// Selected word, memorisation, share cards.
  focus,

  /// Search results, context sheet.
  compact,
}

/// How Quran text is aligned (`align` of `QuranText` in index.jsx).
enum QuranTextAlign { justify, center, start }

/// The only container for Quran text.
///
/// [text] is a [PackText] read from a verified pack; its [PackText.verbatim]
/// is drawn exactly as given, never trimmed, joined, split or changed here.
/// It is set in the Quran font alone, in `quran-ink`, right to left, with no
/// weight, slant, spacing, decoration or shadow, whatever the surrounding text
/// style or the system's bold-text setting.
final class QuranText extends StatelessWidget {
  const QuranText(
    this.text, {
    this.size = QuranTextSize.page,
    this.align = QuranTextAlign.justify,
    super.key,
  });

  final PackText text;
  final QuranTextSize size;
  final QuranTextAlign align;

  @override
  Widget build(BuildContext context) => RichText(
    // RichText rather than Text: Text merges the ambient style and the
    // system's bold-text setting into its style, and neither may reach here.
    text: TextSpan(
      text: text.verbatim,
      style: _styleOf(size).copyWith(color: context.colors.quranInk),
      locale: _arabic,
    ),
    // bundle.css: only .qk-quran-page justifies, .qk-quran-center centres.
    // The page size also centres its last line in the reference
    // (`text-align-last: center`); Flutter has no such option yet (S1, M1.2).
    textAlign: switch ((align, size)) {
      (QuranTextAlign.justify, QuranTextSize.page) => TextAlign.justify,
      (QuranTextAlign.center, _) => TextAlign.center,
      _ => TextAlign.start,
    },
    textDirection: TextDirection.rtl,
    locale: _arabic,
    textScaler: MediaQuery.textScalerOf(context),
  );
}

TextStyle _styleOf(QuranTextSize size) => switch (size) {
  QuranTextSize.page => AppTextStyles.quranPage,
  QuranTextSize.ayah => AppTextStyles.quranAyah,
  QuranTextSize.focus => AppTextStyles.quranFocus,
  QuranTextSize.compact => _quranCompact,
};

const Locale _arabic = Locale('ar');

// .qk-quran-compact: `font-size: 22px; line-height: 2.2`, with .qk-quran's
// family, weight 400 and no letter spacing. The one Quran style tokens.json
// does not define; built like the generated ones.
const TextStyle _quranCompact = TextStyle(
  fontFamily: AppFonts.quran,
  fontSize: 22,
  height: 2.2,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
