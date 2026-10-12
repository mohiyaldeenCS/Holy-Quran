import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/utils/result.dart';

/// A query of a golden query file and the occurrences (مواضع) it must find.
typedef GoldenQuery = ({int line, String query, int expected});

/// A golden query whose search found another count, or failed.
final class GoldenMismatch {
  const GoldenMismatch(this.query, {this.found, this.error});

  final GoldenQuery query;
  final int? found;
  final Exception? error;

  @override
  String toString() =>
      'line ${query.line}: "${query.query}" expected ${query.expected}, '
      '${error != null ? 'failed with $error' : 'found $found'}';
}

/// Reads a golden query file of B0.10: one query per line, then a tab, then
/// the number of occurrences it finds. Blank lines are skipped. Throws a
/// [FormatException] naming the first malformed line.
List<GoldenQuery> parseGoldenQueries(String source) {
  final queries = <GoldenQuery>[];
  for (final (index, line) in source.split('\n').indexed) {
    if (line.trim().isEmpty) continue;
    final fields = line.split('\t');
    final expected = fields.length == 2 ? int.tryParse(fields[1]) : null;
    if (expected == null || expected < 0 || fields[0].trim().isEmpty) {
      throw FormatException('Not "query<TAB>count"', line, index + 1);
    }
    queries.add((line: index + 1, query: fields[0], expected: expected));
  }
  return queries;
}

/// Runs each of [queries] through [search] and returns every mismatch, in
/// file order; none when every count is exact.
Future<List<GoldenMismatch>> runGoldenQueries(
  List<GoldenQuery> queries,
  Future<Result<SearchResults>> Function(String query) search,
) async => [for (final query in queries) ?await _mismatch(query, search)];

Future<GoldenMismatch?> _mismatch(
  GoldenQuery query,
  Future<Result<SearchResults>> Function(String query) search,
) async => switch (await search(query.query)) {
  Ok(value: SearchResults(:final occurrences))
      when occurrences == query.expected =>
    null,
  Ok(value: SearchResults(:final occurrences)) => GoldenMismatch(
    query,
    found: occurrences,
  ),
  Failure(:final error) => GoldenMismatch(query, error: error),
};
