import 'package:flutter_test/flutter_test.dart';

import '../../../testing/fakes/fake_keep_awake_repository.dart';

void main() {
  test('is awake while the setting is on and something is active', () async {
    final keepAwake = FakeKeepAwakeRepository();
    var notified = 0;
    keepAwake.addListener(() => notified++);

    await keepAwake.setReaderActive(true);
    expect(keepAwake.awake, isTrue);
    await keepAwake.setPlayerActive(true);
    await keepAwake.setSettingOn(false);
    expect(keepAwake.awake, isFalse);
    expect(notified, 2);
  });
}
