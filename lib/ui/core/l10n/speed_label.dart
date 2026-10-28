import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';

/// The speed as the Screens2 chip writes it, «١٫٠×»: Arabic-Indic digits and
/// at least one decimal; the separator and the sign are the pattern's.
String speedLabel(AppLocalizations l10n, PlaybackSpeed speed) {
  final hundredths = (speed.factor * 100).round();
  final fraction = hundredths % 100;
  return l10n.playerSpeedValue(
    arabicDigits(hundredths ~/ 100),
    fraction % 10 == 0 ? arabicDigits(fraction ~/ 10) : arabicDigits(fraction),
  );
}
