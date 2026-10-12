import 'package:holyquran/data/repositories/integrity_log_repository.dart';
import 'package:holyquran/utils/result.dart';

/// A fixed integrity log for view tests.
final class FakeIntegrityLogRepository extends IntegrityLogRepository {
  FakeIntegrityLogRepository({this.log = const [], this.lastError});

  /// The entries, newest first.
  final List<IntegrityLogEntry> log;

  @override
  final Exception? lastError;

  @override
  Future<Result<List<IntegrityLogEntry>>> entries() async => Ok(log);
}
