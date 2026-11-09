import 'package:flutter_test/flutter_test.dart';

import 'a11y_support.dart';
import 'screens.dart';

// P1-35: what AX-01, AX-02, AX-04, AX-09, NF-11 and NF-18 ask of every
// screen, at the four sizes of NF-11 and at 200% text on the narrowest phone.
void main() {
  final world = A11yWorld();
  setUpAll(world.open);
  tearDownAll(world.close);

  for (final MapEntry(:key, :value) in {
    for (final view in a11yViews) view.name: view,
  }.entries) {
    group(key, () {
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
        testWidgets('$name is accessible', (tester) async {
          final screen = world.screens.firstWhere((s) => s.name == name);
          await screen.pump(tester, value.size, value.textScale);
          await expectAccessible(tester);
        });
      }
    });
  }
}
