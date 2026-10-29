import '../../testing/flows/flow_rig.dart';
import '../../testing/flows/flow_scenarios.dart';

void main() {
  FlowRig().test(
    'the app opens at the ayah where the last session stopped reading when '
    'the user asked for it, and on home when he did not',
    reopenAtLastPosition,
  );
}
