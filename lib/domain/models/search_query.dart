import 'query_fold.dart';

/// How the words of a query must stand in an ayah (`SR-02`).
enum SearchMode {
  /// They are the whole ayah, in order.
  wholeAyah,

  /// They follow one another, in order, somewhere in the ayah.
  phrase,

  /// Each is somewhere in the ayah, in any order.
  scattered,
}

/// Where a search looks (`SR-06`).
sealed class SearchScope {
  const SearchScope();
}

final class WholeQuran extends SearchScope {
  const WholeQuran();

  @override
  bool operator ==(Object other) => other is WholeQuran;

  @override
  int get hashCode => (WholeQuran).hashCode;

  @override
  String toString() => 'WholeQuran()';
}

final class SurahScope extends SearchScope {
  const SurahScope(this.surah);

  final int surah;

  @override
  bool operator ==(Object other) => other is SurahScope && other.surah == surah;

  @override
  int get hashCode => Object.hash(SurahScope, surah);

  @override
  String toString() => 'SurahScope($surah)';
}

final class JuzScope extends SearchScope {
  const JuzScope(this.juz);

  final int juz;

  @override
  bool operator ==(Object other) => other is JuzScope && other.juz == juz;

  @override
  int get hashCode => Object.hash(JuzScope, juz);

  @override
  String toString() => 'JuzScope($juz)';
}

/// A search of the Quran: [text] as typed, compared through [QueryFold] with
/// the pack's search forms of [kind] (`SR-03`, D-037).
final class SearchQuery {
  SearchQuery({
    required this.text,
    required this.kind,
    required this.mode,
    this.scope = const WholeQuran(),
  }) : words = List.unmodifiable(QueryFold.words(text));

  final String text;
  final String kind;
  final SearchMode mode;
  final SearchScope scope;

  /// The folded words of [text].
  final List<String> words;
}
