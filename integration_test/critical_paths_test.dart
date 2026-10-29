import 'package:flutter_test/flutter_test.dart';

import '../test/flows/copy_scenario.dart';
import '../testing/flows/flow_rig.dart';
import '../testing/flows/flow_scenarios.dart';

// The critical paths of NF-20 on a device, over the same synthetic pack as
// test/flows/, with the plugins the app uses there: the application-support
// folder, the user's database on its own isolate and the system clipboard.
// What stays replaced is named in testing/flows/flow_session.dart.
//
// Run: flutter test integration_test/critical_paths_test.dart -d <device>.
// The command needs `integration_test: sdk: flutter` under dev_dependencies in
// pubspec.yaml. These runs are pending until the owner or the lead makes them
// on an Android and an iOS device.

void main() {
  final rig = FlowRig(onDevice: true);

  rig.test(
    'an ayah is bookmarked in two taps and the bookmark survives a '
    'restart',
    bookmarkInTwoTaps,
  );

  rig.test(
    'the app opens at the ayah where the last session stopped reading',
    reopenAtLastPosition,
  );

  rig.test(
    'a search finds the ayah and its result opens the reader at that ayah',
    searchAndOpenResult,
  );

  rig.test(
    'every ayah of the synthetic pack is copied to the system clipboard as '
    'the pack stores it',
    copyEverySyntheticAyah,
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'an ayah set to repeat three times is heard exactly three times',
    () {},
    skip:
        'pending: it needs a recitation pack with audio files to play on the '
        'device (P1-33), and the real audio engine',
  );

  test(
    'a pack is downloaded, verified, activated, deleted and downloaded again',
    () {},
    skip:
        'pending: the real downloader needs a host the device may fetch from '
        'over HTTPS; the loopback server speaks plain HTTP, which Android '
        'refuses',
  );
}
