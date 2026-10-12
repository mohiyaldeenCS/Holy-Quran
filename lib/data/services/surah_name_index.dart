import '../../domain/models/surah_info.dart';

/// Surah numbers by the names the pack stores, for the names typed into a
/// direct jump. A sink of D-114: it reads the stored names only to compare
/// them with the query, whole and unchanged.
final class SurahNameIndex {
  SurahNameIndex(Iterable<SurahInfo> surahs)
    : _numbers = {
        for (final surah in surahs)
          _comparable(surah.name.verbatim): surah.number,
      };

  final Map<String, int> _numbers;

  /// The number of the surah whose name is [query], or null. The query
  /// arrives trimmed by the direct-jump parser.
  int? surahNamed(String query) => _numbers[_comparable(query)];
}

/// The one form names and queries are compared in; until P1-21 decides
/// otherwise a name matches only exactly. The shared query fold may apply to
/// the query; folding the stored names as well changes pack text in a sink
/// and needs a decision of its own (D-118 folds only the query and the
/// stored search forms).
String _comparable(String name) => name;
