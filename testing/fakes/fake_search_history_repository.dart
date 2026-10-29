import 'package:holyquran/data/repositories/search_history_repository.dart';
import 'package:holyquran/utils/result.dart';

/// An in-memory search history for view tests, newest first.
final class FakeSearchHistoryRepository extends SearchHistoryRepository {
  FakeSearchHistoryRepository([Iterable<String> queries = const []])
    : _queries = [...queries];

  final List<String> _queries;

  /// While set, clearing fails with it and keeps the queries.
  Exception? clearFailure;

  @override
  Future<Result<List<String>>> queries() async => Ok([..._queries]);

  @override
  Future<Result<void>> record(String query) async {
    if (query.isEmpty) return const Ok(null);
    _queries
      ..remove(query)
      ..insert(0, query);
    notifyListeners();
    return const Ok(null);
  }

  @override
  Future<Result<void>> clear() async {
    if (clearFailure case final failure?) return Failure(failure);
    _queries.clear();
    notifyListeners();
    return const Ok(null);
  }
}
