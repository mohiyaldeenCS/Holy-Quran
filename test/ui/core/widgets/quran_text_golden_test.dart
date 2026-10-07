@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

import '../../../../testing/golden.dart';

// Synthetic, never Quran text.
const _sample = PackText.fromPack('نص تجريبي للاختبار');
const _long = PackText.fromPack(
  'نص تجريبي للاختبار يمتد على أكثر من سطر واحد ليظهر الضبط',
);

void main() {
  testWidgets('QuranText sizes and alignments', (tester) async {
    await expectGoldensInThemes(
      tester,
      'quran_text',
      (context) => const SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuranText(_long),
            QuranText(_sample, align: QuranTextAlign.center),
            QuranText(_sample, size: QuranTextSize.ayah),
            QuranText(_sample, size: QuranTextSize.focus),
            QuranText(
              _sample,
              size: QuranTextSize.compact,
              align: QuranTextAlign.start,
            ),
          ],
        ),
      ),
      surfaceSize: const Size(400, 620),
    );
  });
}
