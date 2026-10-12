import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';

void main() {
  test('each state names itself, a failure with its reason', () {
    expect('${const IntegrityOk()}', 'ok');
    expect('${const IntegrityMissing()}', 'missing');
    expect('${const IntegrityRepairing()}', 'repairing');
    expect(
      '${const IntegrityFailed(SurahHashMismatch('synthetic', 2))}',
      'failed: SurahHashMismatch(synthetic): surah 2',
    );
  });

  test('an event keeps its pack, version, state and time', () {
    final at = DateTime.utc(2026, 10, 12);
    final event = PackIntegrityEvent(
      pack: 'synthetic',
      version: null,
      state: const IntegrityMissing(),
      at: at,
    );
    expect(event.pack, 'synthetic');
    expect(event.version, isNull);
    expect(event.state, isA<IntegrityMissing>());
    expect(event.at, at);
  });
}
