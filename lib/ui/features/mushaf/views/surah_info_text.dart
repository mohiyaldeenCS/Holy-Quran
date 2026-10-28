import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/l10n/ayah_count.dart' as counts;

/// The information line under a surah header (`RD-17`): the place of
/// revelation, the ayah count and the surah's order in the mushaf. Null when
/// the source gives no place of revelation, so that the line is hidden.
String? surahInfoText(AppLocalizations l10n, SurahInfo info) {
  final revelation = switch (info.revelationPlace) {
    RevelationPlace.makki => l10n.revelationMakki,
    RevelationPlace.madani => l10n.revelationMadani,
    null => null,
  };
  if (revelation == null) return null;
  return l10n.surahInfoLine(
    revelation,
    counts.ayahCount(l10n, info.ayahCount),
    arabicDigits(info.number),
  );
}
