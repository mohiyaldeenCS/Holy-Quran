@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import '../../../../testing/golden.dart';

// One, two and three digits; the page size and the ayah-row size.
const _numbers = [5, 42, 286];
const _sizes = [26.0, 36.0];

void main() {
  testWidgets('AyahMarker numbers, sizes and playing', (tester) async {
    await expectGoldensInThemes(
      tester,
      'ayah_marker',
      (context) => goldenColumn([
        for (final playing in [false, true])
          for (final size in _sizes)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.space3,
              children: [
                for (final number in _numbers)
                  AyahMarker(number: number, playing: playing, size: size),
              ],
            ),
      ]),
      surfaceSize: const Size(200, 240),
    );
  });
}
