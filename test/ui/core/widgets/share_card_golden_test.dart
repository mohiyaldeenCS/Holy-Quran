@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';

import '../../../../testing/golden.dart';

// Synthetic ayah and surah name.
const _text = PackText.fromPack('نص تجريبي للاختبار وليس آية');
const _name = PackText.fromPack('اسم تجريبي');

// Share.dc.html: the emerald, paper and night cards draw their ayah at 34,
// 26 and 23px.
const _cards = [
  (design: ShareCardDesign.emerald, fontSize: 34.0),
  (design: ShareCardDesign.paper, fontSize: 26.0),
  (design: ShareCardDesign.night, fontSize: 23.0),
];

void main() {
  testWidgets('the three designs at full size, unchanged in each theme', (
    tester,
  ) async {
    await expectGoldensInThemes(
      tester,
      'share_card',
      (context) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.space4,
        children: [
          for (final (:design, :fontSize) in _cards)
            ShareCard(
              ayah: _text,
              surahName: _name,
              ayahNumber: 5,
              ayahFontSize: fontSize,
              design: design,
            ),
        ],
      ),
      surfaceSize: const Size(980, 415),
    );
  });
}
