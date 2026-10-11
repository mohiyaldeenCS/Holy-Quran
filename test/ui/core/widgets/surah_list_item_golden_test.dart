@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/ui/core/widgets/surah_list_item.dart';

import '../../../../testing/golden.dart';

// Synthetic, never a real surah name.
const _name = PackText.fromPack('اسم تجريبي');

void main() {
  testWidgets('SurahListItem, last read, and with no place or page', (
    tester,
  ) async {
    await expectGoldensInThemes(
      tester,
      'surah_list_item',
      (context) => SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SurahListItem(
              number: 1,
              name: _name,
              ayahCount: 7,
              revelation: RevelationPlace.makki,
              page: 1,
              onPressed: () {},
            ),
            SurahListItem(
              number: 2,
              name: _name,
              ayahCount: 286,
              revelation: RevelationPlace.madani,
              page: 2,
              lastRead: true,
              onPressed: () {},
            ),
            SurahListItem(
              number: 114,
              name: _name,
              ayahCount: 6,
              onPressed: () {},
            ),
          ],
        ),
      ),
      surfaceSize: const Size(400, 320),
    );
  });
}
