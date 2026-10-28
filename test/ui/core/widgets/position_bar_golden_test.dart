@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/widgets/position_bar.dart';

import '../../../../testing/golden.dart';

// A synthetic name.
const _name = PackText.fromPack('اسم تجريبي');

void main() {
  testWidgets('PositionBar, at 100% and at 200%', (tester) async {
    await expectGoldensInThemes(
      tester,
      'position_bar',
      (context) => SizedBox(
        width: 342,
        child: goldenColumn([
          const PositionBar(surahName: _name, juz: 30, hizb: 60),
          MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: const PositionBar(surahName: _name, juz: 30, hizb: 60),
          ),
        ]),
      ),
      surfaceSize: const Size(390, 160),
    );
  });
}
