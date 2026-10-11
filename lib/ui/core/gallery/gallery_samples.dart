import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';

/// The debug gallery's stand-ins for pack text, and its only producer of
/// [PackText] (D-086). Each is a plainly synthetic ARB string, never Quran
/// text or a real surah name.
abstract final class GallerySamples {
  static PackText text(AppLocalizations l10n) =>
      PackText.fromPack(l10n.sampleText);

  static PackText longText(AppLocalizations l10n) =>
      PackText.fromPack(l10n.sampleLongText);

  static PackText word(AppLocalizations l10n) =>
      PackText.fromPack(l10n.sampleWord);

  static PackText surahName(AppLocalizations l10n) =>
      PackText.fromPack(l10n.sampleSurahName);
}
