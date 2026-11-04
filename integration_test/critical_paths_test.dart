// WARNING: a run on a device ERASES the app's data on that device: the user
// database, settings, installed packs and catalogue under application support
// of com.example.holyquran, which is also the id of an installed build. Run it
// only on a device or emulator that holds nothing to keep.

import 'package:flutter_test/flutter_test.dart';

import '../test/flows/copy_scenario.dart';
import '../testing/flows/flow_rig.dart';
import '../testing/flows/flow_scenarios.dart';

// The critical paths of NF-20 on a device, over the same synthetic pack as
// test/flows/. The application-support folder, the user's database on its own
// isolate and the system clipboard are the device's. Still replaced, as
// testing/flows/flow_session.dart says: the audio engine, the downloader, the
// wakelock, the network probe and the disk probe, so these runs are only
// partly on real plugins. Signature checking is not exercised either: the
// flows accept an unsigned catalogue and pack.
//
// Run: flutter test integration_test/critical_paths_test.dart -d <device>.
// The command needs `integration_test: sdk: flutter` under dev_dependencies in
// pubspec.yaml (D-156). These runs are pending until they are made on an
// Android and an iOS device.

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
        'pending: the rig has no downloaded recitation file to play, so the '
        'real engine has nothing to open and the run stays on a recording '
        'engine',
  );

  test(
    'a pack is downloaded, verified, activated, deleted and downloaded again',
    () {},
    skip:
        'pending: the rig has no host it may fetch from, so the real '
        'downloader has nothing to fetch and the run stays on a loopback '
        'fetcher',
  );
}
