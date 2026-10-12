import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';

import '../../../testing/fakes/fake_pack_integrity_repository.dart';

void main() {
  test('holds the states given and reported, and tells of each', () async {
    final integrity = FakePackIntegrityRepository({
      'synthetic-a': const IntegrityOk(),
    });
    var notified = 0;
    integrity.addListener(() => notified++);
    final events = integrity.events.toList();

    expect(integrity.stateOf('synthetic-a'), isA<IntegrityOk>());
    expect(integrity.stateOf('synthetic-b'), isA<IntegrityMissing>());

    integrity.report(
      'synthetic-a',
      const IntegrityFailed(PackDisabled('synthetic-a')),
      version: 2,
    );

    expect(integrity.stateOf('synthetic-a'), isA<IntegrityFailed>());
    expect(notified, 1);
    expect(integrity.reports.single.version, 2);
    integrity.dispose();
    expect((await events).single.pack, 'synthetic-a');
  });
}
