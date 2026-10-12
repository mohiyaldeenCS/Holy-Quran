import 'package:flutter/foundation.dart';

import 'package:holyquran/data/services/daos/search_history_dao.dart';
import 'package:holyquran/utils/result.dart';

/// The queries searched on this device (`SR-10`). It stays on the device
/// and can be cleared. Listeners hear of every stored change.
abstract class SearchHistoryRepository extends ChangeNotifier {
  /// The queries, newest first, each once.
  Future<Result<List<String>>> queries();

  /// Puts [query] first; an empty query is not kept.
  Future<Result<void>> record(String query);

  Future<Result<void>> clear();
}

/// [SearchHistoryRepository] over the user database.
final class LocalSearchHistoryRepository extends SearchHistoryRepository {
  LocalSearchHistoryRepository(this._dao, {this._now = _utcMilliseconds});

  final SearchHistoryDao _dao;
  final int Function() _now;

  static int _utcMilliseconds() => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<Result<List<String>>> queries() async {
    try {
      return Ok(await _dao.queries());
    } on Exception catch (error) {
      return Failure(error);
    }
  }

  @override
  Future<Result<void>> record(String query) async {
    if (query.isEmpty) return const Ok(null);
    return _change(() => _dao.record(query, at: _now()));
  }

  @override
  Future<Result<void>> clear() => _change(_dao.clear);

  Future<Result<void>> _change(Future<void> Function() change) async {
    try {
      await change();
    } on Exception catch (error) {
      return Failure(error);
    }
    notifyListeners();
    return const Ok(null);
  }
}
