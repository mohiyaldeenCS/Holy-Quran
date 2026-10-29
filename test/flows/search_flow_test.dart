import '../../testing/flows/flow_rig.dart';
import '../../testing/flows/flow_scenarios.dart';

void main() {
  FlowRig().test(
    'a search finds the ayah, shows it as the pack holds it, and its result '
    'opens the reader at that ayah',
    searchAndOpenResult,
  );
}
