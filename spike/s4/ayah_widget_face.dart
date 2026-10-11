import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

/// The two looks of the ayah widget: the paper widget Share.dc.html draws,
/// and the same widget mapped role by role onto the night theme's tokens for
/// the system's dark mode (WG-04; D-093, reading 1).
enum WidgetLook {
  paper(ReadingTheme.paper),
  night(ReadingTheme.night);

  const WidgetLook(this.theme);

  final ReadingTheme theme;
}

/// What the home-screen ayah widget shows (S4 approach A, D-094): the ayah
/// in the app's own [QuranText] with its reference under it, in two frames,
/// rendered to an image in Flutter so that no Quran text leaves Dart.
///
/// It renders as a root with no app above it, so it supplies its own media
/// query, localizations and theme. Like the share card it is an exported
/// image: it ignores the system text scale and bold-text setting. It paints
/// its ground over the whole of [size] with square corners; the launcher's
/// container clips it to the system's radius (D-093, reading 3). The 2x2 face
/// is the same face at its [size] (D-093, reading 1). The caller fits the
/// ayah with `fitQuranSize` into [ayahBoxOf] (WG-03).
final class AyahWidgetFace extends StatelessWidget {
  const AyahWidgetFace({
    required this.ayah,
    required this.surahName,
    required this.ayahNumber,
    required this.quranSize,
    required this.look,
    required this.size,
    super.key,
  });

  final PackText ayah;
  final PackText surahName;
  final int ayahNumber;

  /// At least 22: [QuranText.card] asserts it.
  final double quranSize;
  final WidgetLook look;
  final Size size;

  /// The box the ayah may fill in a face of [size]: inside the padding and
  /// both frames, less the gap and one line of the reference.
  static Size ayahBoxOf(Size size) {
    final reference = TextPainter(
      text: TextSpan(
        text: arabicDigits(1),
        style: _referenceStyle,
        locale: _arabic,
      ),
      textDirection: TextDirection.rtl,
      locale: _arabic,
      textScaler: TextScaler.noScaling,
    )..layout();
    final referenceHeight = reference.height;
    reference.dispose();
    return Size(
      size.width - 2 * _contentInset,
      size.height - 2 * _contentInset - _gap - referenceHeight,
    );
  }

  @override
  Widget build(BuildContext context) => MediaQuery(
    // A fresh query: no system text scale, no bold text.
    data: const MediaQueryData(textScaler: TextScaler.noScaling),
    child: Localizations(
      locale: _arabic,
      delegates: AppLocalizations.localizationsDelegates,
      child: Theme(
        data: buildAppTheme(look.theme),
        child: SizedBox.fromSize(
          size: size,
          child: _Frames(
            ayah: ayah,
            surahName: surahName,
            ayahNumber: ayahNumber,
            quranSize: quranSize,
          ),
        ),
      ),
    ),
  );
}

final class _Frames extends StatelessWidget {
  const _Frames({
    required this.ayah,
    required this.surahName,
    required this.ayahNumber,
    required this.quranSize,
  });

  final PackText ayah;
  final PackText surahName;
  final int ayahNumber;
  final double quranSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.ground,
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Container(
          padding: const EdgeInsets.all(_framePadding),
          decoration: BoxDecoration(
            border: Border.all(color: colors.ornament, width: _frameWidth),
            borderRadius: BorderRadius.circular(AppRadius.radiusButton),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.ornamentSoft),
              borderRadius: BorderRadius.circular(_innerRadius),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: _gap,
                children: [
                  QuranText.card(ayah, fontSize: quranSize),
                  SurahName(
                    surahName,
                    format: SurahNameFormat.withAyah,
                    ayah: ayahNumber,
                    textAlign: TextAlign.center,
                    style: _referenceStyle.copyWith(color: colors.accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const Locale _arabic = Locale('ar');

// Share.dc.html line 89, the ayah widget: `padding:10px` inside its #F8F2E4
// (ground). Its `width:364px;height:170px;border-radius:24px` are the
// caller's size and the launcher's clip.
const double _padding = 10;

// Share.dc.html line 90, the frame: `border:1.5px solid #B8862B` (ornament),
// `border-radius:16px` (radius-button), `padding:3px`.
const double _frameWidth = 1.5;
const double _framePadding = 3;

// Share.dc.html line 90, the inner frame: `border:1px solid #D9AE5A`
// (ornament-soft), `border-radius:13px`, its column `gap:2px`.
const double _innerRadius = 13;
const double _gap = 2;

/// The inner frame's 1px border.
const double _innerFrameWidth = 1;

/// From the face's edge to the inside of the inner frame.
const double _contentInset =
    _padding + _frameWidth + _framePadding + _innerFrameWidth;

// Share.dc.html line 92, the reference: `font-size:13px;font-weight:600`
// in #8A6212 (accent), IBM Plex Sans Arabic from the board's root, no line
// height set: the font's own, as a TextStyle with no height draws it.
const TextStyle _referenceStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
