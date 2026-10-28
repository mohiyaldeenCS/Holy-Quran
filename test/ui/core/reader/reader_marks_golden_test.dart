@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/reader/margin_mark.dart';
import 'package:holyquran/ui/core/reader/page_mark.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('margin marks: first quarter, later quarter, hizb, juz, sajda', (
    tester,
  ) async {
    await expectGoldensInThemes(
      tester,
      'margin_marks',
      (context) => goldenColumn(const [
        MarginMarkView(MarginMark(MarginMarkKind.rub, 5, hizb: 3, quarter: 1)),
        MarginMarkView(MarginMark(MarginMarkKind.rub, 9, hizb: 3, quarter: 2)),
        MarginMarkView(MarginMark(MarginMarkKind.hizb, 12, hizb: 4)),
        MarginMarkView(MarginMark(MarginMarkKind.juz, 20, juz: 30)),
        MarginMarkView(MarginMark(MarginMarkKind.sajda, 26)),
      ]),
      surfaceSize: const Size(300, 420),
    );
  });

  testWidgets('page marks of one to three digits in a marker place', (
    tester,
  ) async {
    await expectGoldensInThemes(
      tester,
      'page_marks',
      (context) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.space4,
        children: [
          for (final page in [3, 42, 604])
            SizedBox.square(
              dimension: AppSizes.ayahMarker,
              child: PageMark(page: page),
            ),
        ],
      ),
      surfaceSize: const Size(300, 100),
    );
  });
}
