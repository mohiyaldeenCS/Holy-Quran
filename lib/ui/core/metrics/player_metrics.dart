import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The layout of the listen screen, measured from the player of
/// `design/identity-boards/Screens2.dc.html` («المشغّل · النطاق والتكرار في
/// متناول اليد»). The recitation picker, which the identity does not draw,
/// follows it.
abstract final class PlayerMetrics {
  // Screens2: the content block under the header, `padding:4px 20px 0`.
  static const EdgeInsets bodyPadding = EdgeInsets.fromLTRB(
    _bodySide,
    AppSpacing.space1,
    _bodySide,
    0,
  );
  static const double _bodySide = 20;

  // Screens2: the header, `padding:24px 16px 8px`.
  static const EdgeInsets headerPadding = EdgeInsets.fromLTRB(
    AppSpacing.space4,
    AppSpacing.space5,
    AppSpacing.space4,
    AppSpacing.space2,
  );

  // Screens2: the reciter card, `padding:12px 14px;border-radius:20px`.
  static const EdgeInsets reciterCardPadding = EdgeInsets.symmetric(
    vertical: AppSpacing.space3,
    horizontal: 14,
  );
  static const BorderRadius reciterCardRadius = BorderRadius.all(
    Radius.circular(20),
  );

  // Screens2: «تغيير» is a bare span, so the focus outline around it is
  // square.
  static const BorderRadius changeFocusRadius = BorderRadius.zero;

  // Screens2: the reciter card's badge, a 48 circle holding the star
  // `width="34"`; its `stroke-width="5"` is StarOutline's own.
  static const double reciterStarSize = 34;

  // Screens2: the reciter's line, the page and the position line,
  // `font-size:13px`; the body's IBM Plex Sans Arabic at weight 400 with its
  // `normal` line height, as in MiniPlayer.
  static const TextStyle smallText = TextStyle(
    inherit: false,
    fontFamily: AppFonts.sans,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // Screens2: «تغيير», `font-size:15px;font-weight:600`.
  static final TextStyle changeText = smallText.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  // Screens2: the emerald card, `border-radius:32px 32px 0 0;
  // padding:18px 20px 22px;gap:14px`.
  static const BorderRadius panelRadius = BorderRadius.vertical(
    top: Radius.circular(32),
  );
  static const EdgeInsets panelPadding = EdgeInsets.fromLTRB(
    _bodySide,
    18,
    _bodySide,
    22,
  );
  static const double panelGap = 14;

  // Screens2: the track over the position line, `gap:6px`.
  static const double trackGap = 6;

  // Screens2: the main button, `width:72px;height:72px`, its glyph
  // `width="32"`.
  static const double mainButtonSize = 72;
  static const double mainIconSize = 32;

  // Screens2: the chips under the buttons and the repeat button's ground,
  // `rgba(248,242,228,0.14)`: on-player at 14%.
  static const double tintOpacity = 0.14;

  // Screens2: a chip, `height:36px;padding:0 14px;border-radius:18px`
  // (half its height), `font-size:14px;font-weight:600`.
  static const double chipHeight = 36;
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(horizontal: 14);
  // Half the height at any text scale: radius-full.
  static const BorderRadius chipRadius = BorderRadius.all(
    Radius.circular(AppRadius.radiusFull),
  );
  static final TextStyle chipText = smallText.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  // Not from the board, which draws no mini player over the tab bar: its gaps
  // are the spacing scale's.
  static const EdgeInsets miniPlayerPadding = EdgeInsets.fromLTRB(
    AppSpacing.space4,
    AppSpacing.space2,
    AppSpacing.space4,
    AppSpacing.space2,
  );

  // Not from the board: how far one screen-reader increase or decrease
  // moves the position, as the board draws a track and no step.
  static const Duration seekStep = Duration(seconds: 5);
}

/// The speed as the Screens2 chip writes it, «١٫٠×»: Arabic-Indic digits,
/// the Arabic decimal separator (docs/DESIGN_SYSTEM.md, "Ground rules" 6)
/// and at least one decimal.
String playerSpeedLabel(PlaybackSpeed speed) {
  final hundredths = (speed.factor * 100).round();
  final fraction = hundredths % 100;
  final decimals = fraction % 10 == 0
      ? arabicDigits(fraction ~/ 10)
      : arabicDigits(fraction);
  return '${arabicDigits(hundredths ~/ 100)}'
      '${String.fromCharCode(_arabicDecimalSeparator)}$decimals$_times';
}

const int _arabicDecimalSeparator = 0x066B;
const String _times = '×';
