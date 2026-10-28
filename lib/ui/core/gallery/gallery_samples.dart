import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';

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

  /// A one-ayah synthetic surah of [text]. Its word spans are cut at the
  /// sample's spaces, which gives the reader the spans a pack would.
  static SurahText surah(
    AppLocalizations l10n, {
    required String riwaya,
    required int number,
  }) {
    final raw = l10n.sampleText;
    final words = <WordSpan>[];
    var start = 0;
    while (start < raw.length) {
      final space = raw.indexOf(' ', start);
      final end = space < 0 ? raw.length : space;
      words.add(WordSpan(number: words.length + 1, start: start, end: end));
      start = end + 1;
    }
    return SurahText(
      riwaya: riwaya,
      surah: number,
      ayat: [AyahText(text: text(l10n), words: words)],
    );
  }
}
