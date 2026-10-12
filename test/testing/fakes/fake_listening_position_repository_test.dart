import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/listening_position.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import '../../../testing/fakes/fake_listening_position_repository.dart';

void main() {
  test('remembers saves and notifies on a change', () async {
    final positions = FakeListeningPositionRepository();
    var notified = 0;
    positions.addListener(() => notified++);
    final position = ListeningPosition(
      address: QuranAddress.parse('hafs:2:5'),
      recitationId: 'synthetic-reciter',
      offset: Duration.zero,
    );

    await positions.save(position);
    await positions.save(position);

    expect(positions.last, position);
    expect(positions.saved, hasLength(2));
    expect(notified, 1);
  });
}
