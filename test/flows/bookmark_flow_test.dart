import '../../testing/flows/flow_rig.dart';
import '../../testing/flows/flow_scenarios.dart';

void main() {
  FlowRig().test(
    'an ayah is bookmarked in two taps, and the bookmark survives a restart '
    'of the app',
    bookmarkInTwoTaps,
  );
}
