import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';

const int _bytesPerMegabyte = 1000000;
const int _tenthsPerMegabyte = 10;
final String _decimalMark = String.fromCharCode(
  0x066B,
); // ARABIC DECIMAL SEPARATOR

/// A size in megabytes with one decimal, in Arabic-Indic digits. It rounds up
/// to the tenth so that a file that exists never reads as «٠٫٠».
String megabytes(AppLocalizations l10n, int bytes) {
  final tenths =
      (bytes * _tenthsPerMegabyte + _bytesPerMegabyte - 1) ~/ _bytesPerMegabyte;
  final whole = arabicDigits(tenths ~/ _tenthsPerMegabyte);
  final fraction = arabicDigits(tenths % _tenthsPerMegabyte);
  return l10n.resourceSizeMegabytes('$whole$_decimalMark$fraction');
}
