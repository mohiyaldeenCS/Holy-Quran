import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';

/// A count of ayat in correct Arabic: the plural form is chosen from [n] and
/// the number is written by [arabicDigits], not by the locale.
String ayahCount(AppLocalizations l10n, int n) =>
    l10n.ayahCount(n, arabicDigits(n));
