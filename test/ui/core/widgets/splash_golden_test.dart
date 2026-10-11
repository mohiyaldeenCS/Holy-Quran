@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/widgets/splash.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('the lockup on emerald, unchanged in each theme', (tester) async {
    await expectGoldensInThemes(
      tester,
      'splash',
      (context) => const SizedBox(width: 300, height: 650, child: Splash()),
      surfaceSize: const Size(340, 690),
    );
  });
}
