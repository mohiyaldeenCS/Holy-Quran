import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/mark.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

/// The three designs of the ayah share card (Share.dc.html).
enum ShareCardDesign { emerald, paper, night }

/// The ayah share card in its 4:5 size (SH-02; D-089, 2): the ayah, its
/// reference under it, and the small mark and name at the foot.
///
/// It is an exported image, so its colours are fixed per [design] whatever
/// the app's theme (the paper and night cards take the `paper` and `night`
/// themes' tokens), and it ignores the system text scale (D-085) and the
/// system's bold-text setting, which would draw the reference at 700. The
/// caller fits the ayah by [ayahFontSize] (SH-03).
final class ShareCard extends StatelessWidget {
  const ShareCard({
    required this.ayah,
    required this.surahName,
    required this.ayahNumber,
    required this.ayahFontSize,
    this.design = ShareCardDesign.emerald,
    super.key,
  });

  final PackText ayah;
  final PackText surahName;
  final int ayahNumber;
  final double ayahFontSize;
  final ShareCardDesign design;

  @override
  Widget build(BuildContext context) {
    final content = _Content(
      ayah: ayah,
      surahName: surahName,
      ayahNumber: ayahNumber,
      ayahFontSize: ayahFontSize,
      design: design,
    );
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.noScaling, boldText: false),
      child: SizedBox(
        width: _cardWidth,
        height: _cardHeight,
        child: switch (design) {
          ShareCardDesign.emerald => _EmeraldCard(content: content),
          ShareCardDesign.paper => Theme(
            data: buildAppTheme(ReadingTheme.paper),
            child: _PaperCard(content: content),
          ),
          ShareCardDesign.night => Theme(
            data: buildAppTheme(ReadingTheme.night),
            child: _NightCard(content: content),
          ),
        },
      ),
    );
  }
}

final class _EmeraldCard extends StatelessWidget {
  const _EmeraldCard({required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Ramps.emerald700,
      borderRadius: BorderRadius.circular(_cardRadius),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        for (final star in _emeraldStars)
          Positioned(
            left: star.left,
            top: star.top,
            child: StarOutline(
              size: star.size,
              stroke: _starStroke,
              color: Ramps.gold400.withValues(alpha: star.opacity),
            ),
          ),
        Padding(padding: _emeraldPadding, child: content),
      ],
    ),
  );
}

final class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(_paperPadding),
      decoration: BoxDecoration(
        color: colors.ground,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space1),
        decoration: BoxDecoration(
          border: Border.all(
            color: colors.ornament,
            width: _paperOuterFrameWidth,
          ),
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
        child: Container(
          padding: _paperInnerPadding,
          decoration: BoxDecoration(
            border: Border.all(color: colors.ornamentSoft),
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
          ),
          child: content,
        ),
      ),
    );
  }
}

final class _NightCard extends StatelessWidget {
  const _NightCard({required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.ground,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: _nightStar.left,
            top: _nightStar.top,
            child: StarOutline(
              size: _nightStar.size,
              stroke: _starStroke,
              color: colors.ornament.withValues(alpha: _nightStar.opacity),
            ),
          ),
          Padding(padding: _nightPadding, child: content),
        ],
      ),
    );
  }
}

/// What the three cards share: the ayah and its reference centred in the
/// free height, and the mark with the name at the foot.
final class _Content extends StatelessWidget {
  const _Content({
    required this.ayah,
    required this.surahName,
    required this.ayahNumber,
    required this.ayahFontSize,
    required this.design,
  });

  final PackText ayah;
  final PackText surahName;
  final int ayahNumber;
  final double ayahFontSize;
  final ShareCardDesign design;

  @override
  Widget build(BuildContext context) {
    final emerald = design == ShareCardDesign.emerald;
    final colors = emerald ? null : context.colors;
    final look = switch (design) {
      ShareCardDesign.emerald => _emeraldLook,
      ShareCardDesign.paper => _paperLook,
      ShareCardDesign.night => _nightLook,
    };
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: look.gap,
            children: [
              if (design == ShareCardDesign.paper)
                const StarOutline(size: _paperStarSize),
              QuranText.card(
                ayah,
                fontSize: ayahFontSize,
                colour: emerald
                    ? QuranTextColour.onEmerald
                    : QuranTextColour.quranInk,
              ),
              SurahName(
                surahName,
                format: SurahNameFormat.withAyah,
                ayah: ayahNumber,
                textAlign: TextAlign.center,
                style: _referenceStyle.copyWith(
                  fontSize: look.referenceSize,
                  color: colors?.accent ?? Ramps.gold400,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.space2,
          children: [
            Semantics(
              container: true,
              image: true,
              label: AppLocalizations.of(context).markLabel,
              child: Mark(
                size: look.markSize,
                variant: emerald ? MarkVariant.emerald : MarkVariant.paper,
                decorative: true,
              ),
            ),
            Text(
              AppLocalizations.of(context).appTitle,
              softWrap: false,
              style: _nameStyle.copyWith(
                fontSize: look.nameSize,
                color: colors?.brandInk ?? Ramps.paper100,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Share.dc.html, the three cards: `width:300px;height:375px;
// border-radius:20px`, the 4:5 size.
const double _cardWidth = 300;
const double _cardHeight = 375;
const double _cardRadius = 20;

// Share.dc.html, emerald card: `padding:28px 26px 20px`; night card:
// `padding:28px 24px 20px`.
const EdgeInsets _emeraldPadding = EdgeInsets.fromLTRB(26, 28, 26, 20);
const EdgeInsets _nightPadding = EdgeInsets.fromLTRB(24, 28, 24, 20);

// Share.dc.html, the background stars: `stroke-width="0.8"` in the 120
// viewBox, unfilled, at `left`, `top`, size and `stroke-opacity` each. The
// emerald card's are #D9AE5A (gold-400); the night card's is the night
// theme's #D9AE5A (ornament).
const double _starStroke = 0.8;
const _emeraldStars = [
  (left: -90.0, top: -90.0, size: 280.0, opacity: 0.28),
  (left: 170.0, top: 230.0, size: 220.0, opacity: 0.18),
];
const _nightStar = (left: 60.0, top: -120.0, size: 300.0, opacity: 0.16);

// Share.dc.html, paper card: `padding:14px` inside its 1px #DDD2B8 (line)
// border; the outer frame `border:1.5px solid #B8862B` (ornament),
// `border-radius:12px` (radius-md), `padding:4px` (space-1); the inner frame
// `border:1px solid #D9AE5A` (ornament-soft), `border-radius:8px`
// (radius-sm), `padding:18px 16px 14px`.
const double _paperPadding = 14;
const double _paperOuterFrameWidth = 1.5;
const EdgeInsets _paperInnerPadding = EdgeInsets.fromLTRB(16, 18, 16, 14);

// Share.dc.html, paper card: `<svg width="26" height="26">` star over the
// ayah, stroke 5 (StarOutline's default) in #B8862B (ornament).
const double _paperStarSize = 26;

typedef _Look = ({
  double gap,
  double referenceSize,
  double markSize,
  double nameSize,
});

// Share.dc.html, each card: the ayah block's `gap`, the reference's
// `font-size`, the mark's `<svg width>` and the name's `font-size`. The mark
// and the name sit `gap:8px` (space-2) apart.
const _Look _emeraldLook = (
  gap: 14,
  referenceSize: 18,
  markSize: 26,
  nameSize: 14,
);
const _Look _paperLook = (
  gap: 12,
  referenceSize: 17,
  markSize: 24,
  nameSize: 13,
);
const _Look _nightLook = (
  gap: 14,
  referenceSize: 17,
  markSize: 24,
  nameSize: 13,
);

// Share.dc.html, the reference: Reem Kufi, `font-weight:600`, no line height
// set: the font's own, as a TextStyle with no height draws it.
const TextStyle _referenceStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.kufi,
  fontFamilyFallback: [AppFonts.sans],
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

// Share.dc.html, the name beside the mark: Reem Kufi, `font-weight:700`, no
// line height set.
const TextStyle _nameStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.kufi,
  fontFamilyFallback: [AppFonts.sans],
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
