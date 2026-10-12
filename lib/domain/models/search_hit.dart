import 'quran_address.dart';
import 'quran_range.dart';
import 'search_match.dart';
import 'search_query.dart';
import 'tafsir_passage.dart';

/// The orders results may be shown in (`SR-05`).
enum SearchOrder {
  /// By ayah, in the mushaf.
  mushaf,

  /// The query's words in order and together first, then the fewest words
  /// between them, then by ayah.
  closeness,

  /// The most occurrences first, then by ayah.
  frequency,
}

/// An ayah a search found, and where in it. The ayah's text is read from the
/// pack by address; [matches] are word ranges, highlighted through the word
/// offsets the pack stores.
final class SearchHit {
  SearchHit({
    required this.ayah,
    required List<QuranRange> matches,
    required this.exact,
    required this.gaps,
  }) : matches = List.unmodifiable(matches) {
    if (ayah.isWord || matches.isEmpty || gaps < 0 || (exact && gaps != 0)) {
      throw ArgumentError('Not a search hit: $ayah, $matches, $exact, $gaps');
    }
    for (final range in matches) {
      if (!range.start.isWord || range.start.ayahAddress != ayah) {
        throw ArgumentError.value(range, 'matches', 'is not words of $ayah');
      }
      if (range.end.ayahAddress != ayah) {
        throw ArgumentError.value(range, 'matches', 'leaves $ayah');
      }
    }
  }

  final QuranAddress ayah;

  /// The words that matched, in order: one range per occurrence of a phrase
  /// or of the whole ayah, one per matching word for scattered words.
  final List<QuranRange> matches;

  /// Whether the query's words stand in the ayah in order and together.
  final bool exact;

  /// The words between the query's words in the shortest stretch of the
  /// ayah holding all of them; 0 when [exact].
  final int gaps;

  int get occurrences => matches.length;

  @override
  String toString() => 'SearchHit($ayah, $matches, exact: $exact, $gaps)';
}

/// What a search of the Quran found: [hits] in mushaf order.
final class SearchResults {
  SearchResults({required this.query, required List<SearchHit> hits})
    : hits = List.unmodifiable(hits),
      occurrences = hits.fold(0, (sum, hit) => sum + hit.occurrences);

  final SearchQuery query;
  final List<SearchHit> hits;

  /// The occurrences (مواضع) of every hit.
  final int occurrences;

  int get ayat => hits.length;

  /// [hits] in [order]; mushaf order breaks every tie.
  List<SearchHit> ordered(SearchOrder order) => switch (order) {
    SearchOrder.mushaf => hits,
    SearchOrder.closeness => [...hits]..sort(_byCloseness),
    SearchOrder.frequency => [...hits]..sort(_byFrequency),
  };

  static int _byMushaf(SearchHit a, SearchHit b) => a.ayah.compareTo(b.ayah);

  static int _byCloseness(SearchHit a, SearchHit b) {
    if (a.exact != b.exact) return a.exact ? -1 : 1;
    final byGaps = a.gaps.compareTo(b.gaps);
    return byGaps != 0 ? byGaps : _byMushaf(a, b);
  }

  static int _byFrequency(SearchHit a, SearchHit b) {
    final byCount = b.occurrences.compareTo(a.occurrences);
    return byCount != 0 ? byCount : _byMushaf(a, b);
  }
}

/// A tafsir passage a search found (`TF-07`): the passage of book [book], a
/// pack id, as stored, and where the query occurs in its text.
final class TafsirHit {
  TafsirHit({
    required this.book,
    required this.passage,
    required List<SearchMatch> matches,
  }) : matches = List.unmodifiable(matches) {
    if (matches.isEmpty) {
      throw ArgumentError.value(matches, 'matches', 'is empty');
    }
  }

  final String book;
  final TafsirPassage passage;

  /// Offsets into the passage's text, in order and not overlapping.
  final List<SearchMatch> matches;
}
