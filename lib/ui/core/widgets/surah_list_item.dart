import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/l10n/ayah_count.dart' as counts;
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

// .qk-surah-item: gap 14px.
const double _gap = 14;
// .qk-surah-item-no: width and height 44px; SurahListItem in index.jsx:
// <StarOutline size={44} stroke={4} />.
const double _numberBoxSize = 44;
const double _numberStarStroke = 4;
// .qk-surah-item-main: gap 2px.
const double _mainGap = 2;
// .qk-surah-item-page: min-width 40px.
const double _pageMinWidth = 40;
// .qk-badge: gap 6px; height 24px; padding 0 10px. Its border-radius 12px is
// half that height, a pill: the badge is drawn as a stadium, so it stays one
// when the text scale makes it taller.
const double _badgeGap = 6;
const double _badgeHeight = 24;
const double _badgePadding = 10;
// .qk-badge-dot: width and height 6px; border-radius 3px.
const double _badgeDotSize = 6;
const BorderRadius _badgeDotRadius = BorderRadius.all(Radius.circular(3));

// Text with no line height set is drawn at the font's own (CSS `normal`), as a
// style with no height draws it; the styles do not inherit, so the ambient
// body line height cannot reach them.

// .qk-surah-item-no span: font-size 14px; font-weight 600.
const double _numberFontSize = 14;
const TextStyle _numberStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: _numberFontSize,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-surah-item-name: Reem Kufi, font-size 20px; font-weight 600;
// line-height 1.4.
const TextStyle _nameStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.kufi,
  fontFamilyFallback: [AppFonts.sans],
  fontSize: 20,
  height: 1.4,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-surah-item-meta: font-size 14px, in the sans 400.
const TextStyle _metaStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-surah-item-page: font-size 12px, in the sans 400.
const TextStyle _pageWordStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-surah-item-page b: font-size 16px; font-weight 600.
const TextStyle _pageNumberStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 16,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-badge: font-size 12px; font-weight 600.
const TextStyle _badgeStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// A row of the surah index (`SurahListItem`, `.qk-surah-item`): the number
/// inside a quarter star, the name, the place of revelation and the ayah
/// count, and the start page. [lastRead] adds the «آخر قراءة» badge. The
/// whole row is one button.
///
/// [name] is the pack's surah name, drawn by [SurahName]. A [revelation] or
/// [page] the source lacks is not shown.
class SurahListItem extends StatelessWidget {
  const SurahListItem({
    required this.number,
    required this.name,
    required this.ayahCount,
    required this.onPressed,
    this.revelation,
    this.page,
    this.lastRead = false,
    super.key,
  });

  final int number;
  final PackText name;
  final int ayahCount;
  final RevelationPlace? revelation;
  final int? page;
  final bool lastRead;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final count = counts.ayahCount(l10n, ayahCount);
    final meta = switch (revelation) {
      null => count,
      RevelationPlace.makki => l10n.surahListMeta(l10n.revelationMakki, count),
      RevelationPlace.madani => l10n.surahListMeta(
        l10n.revelationMadani,
        count,
      ),
    };
    final page = this.page;
    // The quarter star grows with the text, as AyahMarker's ring does. The
    // number is sized from the star and not scaled again: a non-linear system
    // scale enlarges 14 proportionally more than 44, which would push the
    // number out of the star.
    final numberBox = MediaQuery.textScalerOf(context).scale(_numberBoxSize);
    final face = Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      // .qk-surah-item: padding var(--space-3) 0.
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
      child: Row(
        spacing: _gap,
        children: [
          SizedBox.square(
            dimension: numberBox,
            child: Stack(
              alignment: Alignment.center,
              children: [
                StarOutline(size: numberBox, stroke: _numberStarStroke),
                Text(
                  arabicDigits(number),
                  maxLines: 1,
                  softWrap: false,
                  textScaler: TextScaler.noScaling,
                  style: _numberStyle.copyWith(
                    fontSize: numberBox * _numberFontSize / _numberBoxSize,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: _mainGap,
              children: [
                // .qk-surah-item-name: the name and the badge, gap
                // var(--space-2); the badge moves under a name too long to
                // share its line.
                Wrap(
                  spacing: AppSpacing.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SurahName(
                      name,
                      style: _nameStyle.copyWith(color: colors.ink),
                    ),
                    if (lastRead) const _LastReadBadge(),
                  ],
                ),
                Text(meta, style: _metaStyle.copyWith(color: colors.inkMuted)),
              ],
            ),
          ),
          if (page != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: _pageMinWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.surahListPage,
                    style: _pageWordStyle.copyWith(color: colors.inkMuted),
                  ),
                  Text(
                    arabicDigits(page),
                    style: _pageNumberStyle.copyWith(color: colors.ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    // No label of its own: the row is read as its texts, in order, so the
    // pack's name reaches the screen reader through SurahName unchanged.
    return Semantics(
      container: true,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: BorderRadius.zero,
        child: face,
      ),
    );
  }
}

/// `.qk-badge`: the «آخر قراءة» badge, its dot in `ornament`.
class _LastReadBadge extends StatelessWidget {
  const _LastReadBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: _badgeHeight),
      padding: const EdgeInsets.symmetric(horizontal: _badgePadding),
      decoration: ShapeDecoration(
        color: colors.primarySoft,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: _badgeGap,
        children: [
          Container(
            width: _badgeDotSize,
            height: _badgeDotSize,
            decoration: BoxDecoration(
              color: colors.ornament,
              borderRadius: _badgeDotRadius,
            ),
          ),
          Flexible(
            child: Text(
              AppLocalizations.of(context).surahListLastRead,
              style: _badgeStyle.copyWith(color: colors.onPrimarySoft),
            ),
          ),
        ],
      ),
    );
  }
}
