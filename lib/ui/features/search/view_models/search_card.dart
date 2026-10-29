import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/search_match.dart';

/// What one result card shows: the ayah as the pack stores it, the name of
/// its surah, and where the query matched in the ayah's text. The matches are
/// offsets into [text]; nothing of the text is changed or cut.
final class SearchCard {
  SearchCard({
    required this.ayah,
    required this.surahName,
    required this.text,
    required List<SearchMatch> matches,
  }) : matches = List.unmodifiable(matches);

  final QuranAddress ayah;
  final PackText surahName;
  final PackText text;
  final List<SearchMatch> matches;
}
