@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/copy_form.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/share/share_card_fit.dart';
import 'package:holyquran/ui/core/share/share_card_sheet.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';

import '../../../../testing/golden.dart';

// Synthetic ayah, surah name and reference.
const _text = PackText.fromPack('نص تجريبي للاختبار وليس آية');
const _name = PackText.fromPack('اسم تجريبي');
const _reference = '[اسم تجريبي: ٥]';

const _width = 360.0;

Widget _sized(Widget sheet) => SizedBox(width: _width, child: sheet);

void main() {
  testWidgets('the copy sheet with the form the app offers and with all '
      'three, each with its preview, in each theme', (tester) async {
    await expectGoldensInThemes(
      tester,
      'copy_sheet',
      (context) => goldenColumn([
        for (final forms in [
          [CopyForm.withSurahAndNumber],
          CopyForm.values,
        ])
          _sized(
            CopySheet(
              forms: forms,
              selected: CopyForm.withSurahAndNumber,
              onSelected: (_) {},
              onCopy: () {},
              ayah: _text,
              reference: _reference,
            ),
          ),
      ]),
      // Measured with the app's fonts: 328 and 424 high, 16 apart.
      surfaceSize: const Size(400, 800),
    );
  });

  testWidgets('the share sheet with a card and too long, in each theme', (
    tester,
  ) async {
    await expectGoldensInThemes(
      tester,
      'share_card_sheet',
      (context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: AppSpacing.space4,
        children: [
          for (final card in [
            const ShareCard(
              ayah: _text,
              surahName: _name,
              ayahNumber: 5,
              ayahFontSize: shareCardFontSize,
            ),
            null,
          ])
            _sized(
              ShareCardSheet(
                design: ShareCardDesign.emerald,
                onDesignSelected: (_) {},
                card: card,
                onShare: () {},
                onCopy: () {},
              ),
            ),
        ],
      ),
      surfaceSize: const Size(780, 620),
    );
  });
}
