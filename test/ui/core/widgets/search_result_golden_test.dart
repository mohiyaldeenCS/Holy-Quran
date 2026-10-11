@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';

import '../../../../testing/golden.dart';

// Synthetic, never Quran text or a real surah name.
const _name = PackText.fromPack('اسم تجريبي');
const _short = PackText.fromPack('نص تجريبي للاختبار وليس آية');
const _long = PackText.fromPack(
  'نص تجريبي طويل يمتد على أسطر كثيرة ليظهر قطع الكلام في البطاقة، '
  'وهو نص تجريبي ليس آية ولا مأخوذًا من أي مصدر، ويتكرر ليطول: '
  'نص تجريبي طويل يمتد على أسطر كثيرة ليظهر قطع الكلام في البطاقة.',
);

void main() {
  testWidgets('a whole ayah, and a long one clamped under its fade', (
    tester,
  ) async {
    await expectGoldensInThemes(
      tester,
      'search_result',
      (context) => SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // SearchResult/preview.html: `gap: 10`.
          spacing: 10,
          children: [
            SearchResult(
              surahName: _name,
              ayahNumber: 45,
              ayahText: _short,
              onContext: () {},
              onOpen: () {},
            ),
            SearchResult(
              surahName: _name,
              ayahNumber: 61,
              ayahText: _long,
              clamp: true,
              onContext: () {},
              onOpen: () {},
            ),
          ],
        ),
      ),
      surfaceSize: const Size(460, 460),
    );
  });
}
