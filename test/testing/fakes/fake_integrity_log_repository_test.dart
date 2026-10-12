import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/integrity_log_repository.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_integrity_log_repository.dart';

void main() {
  test('returns its entries and last error', () async {
    final entry = IntegrityLogEntry(
      packId: 'synthetic-text',
      packVersion: null,
      kind: 'missing',
      detail: null,
      occurredAt: DateTime.utc(2026),
    );
    final log = FakeIntegrityLogRepository(
      log: [entry],
      lastError: const FormatException('synthetic failure'),
    );

    expect((await log.entries() as Ok<List<IntegrityLogEntry>>).value, [entry]);
    expect(log.lastError, isA<FormatException>());
  });
}
