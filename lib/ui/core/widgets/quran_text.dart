import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
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

/// The colours the identity draws Quran text in (docs/DESIGN_SYSTEM.md,
/// "Quran text colour"; D-085).
enum QuranTextColour {
  /// `quran-ink`, everywhere except the two places below.
  quranInk,

  /// The selected word at the top of `WordSheet` (`.qk-sheet-word .qk-quran`).
  accent,

  /// The ayah on the emerald share card (`paper-100`, Share board).
  onEmerald,
}

/// The only container for Quran text.
///
/// [text] is a [PackText] read from a verified pack; its [PackText.verbatim]
/// is drawn exactly as given, never trimmed, joined, split or changed here.
/// It is set in the Quran font alone, in [colour], right to left, with no
/// weight, slant, spacing, decoration or shadow, whatever the surrounding text
/// style or the system's bold-text setting.
final class QuranText extends StatelessWidget {
  const QuranText(
    this.text, {
    this.size = QuranTextSize.page,
    this.align = QuranTextAlign.justify,
    this.colour = QuranTextColour.quranInk,
    super.key,
  }) : cardFontSize = null;

  /// The ayah on a share card (D-085, D-089): centred, line height 2.2, at
  /// [fontSize], which the caller fits and which is at least 22. The card is
  /// an exported image, so, like `Lockup`, it ignores the system text scale.
  const QuranText.card(
    this.text, {
    required double fontSize,
    this.colour = QuranTextColour.quranInk,
    super.key,
  }) : assert(fontSize >= _cardMinFontSize),
       cardFontSize = fontSize,
       size = QuranTextSize.focus,
       align = QuranTextAlign.center;

  final PackText text;
  final QuranTextSize size;
  final QuranTextAlign align;
  final QuranTextColour colour;

  /// The card form's font size; null for the sized forms.
  final double? cardFontSize;

  @override
  Widget build(BuildContext context) {
    final cardFontSize = this.cardFontSize;
    final style = cardFontSize == null
        ? _styleOf(size)
        : _quranCard.copyWith(fontSize: cardFontSize);
    return RichText(
      // RichText rather than Text: Text merges the ambient style and the
      // system's bold-text setting into its style, and neither may reach here.
      text: TextSpan(
        text: text.verbatim,
        style: style.copyWith(color: _colourOf(context.colors)),
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
      textScaler: cardFontSize == null
          ? MediaQuery.textScalerOf(context)
          : TextScaler.noScaling,
    );
  }

  Color _colourOf(AppColors colors) => switch (colour) {
    QuranTextColour.quranInk => colors.quranInk,
    QuranTextColour.accent => colors.accent,
    QuranTextColour.onEmerald => Ramps.paper100,
  };
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

// Share.dc.html: the cards' ayah is Amiri Quran at 34, 26 and 23px with
// `line-height: 2.2; text-align: center`; the size is the caller's.
const TextStyle _quranCard = TextStyle(
  fontFamily: AppFonts.quran,
  height: 2.2,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

// D-089 (1): a long ayah shrinks to 22 at the least (SH-03).
const double _cardMinFontSize = 22;
