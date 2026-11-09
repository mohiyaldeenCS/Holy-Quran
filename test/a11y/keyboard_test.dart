import 'package:flutter_test/flutter_test.dart';

import 'a11y_support.dart';
import 'screens.dart';

// AX-09, NF-17 (WCAG 2.1.1): Tab reaches every control a screen reader can
// tap, and each stop shows the identity's focus ring.
void main() {
  final world = A11yWorld();
  setUpAll(world.open);
  tearDownAll(world.close);

  for (final name in [
    'home',
    'mushaf',
    'index',
    'reader',
    'listen',
    'recitations',
    'study',
    'search',
    'more',
    'settings',
    'onboarding',
    'bookmarks',
  ]) {
    testWidgets('$name is reached by Tab, ring at each stop', (tester) async {
      final screen = world.screens.firstWhere((s) => s.name == name);
      await screen.pump(tester, phonePortrait, 1);
      await expectKeyboardReach(
        tester,
        long: name == 'reader' || name == 'mushaf',
      );
    });
  }
}
