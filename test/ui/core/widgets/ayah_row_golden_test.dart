@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';

import '../../../../testing/golden.dart';

// Synthetic, never Quran text.
const _text = PackText.fromPack('نص تجريبي');

void main() {
  testWidgets('AyahRow with every action and with one', (tester) async {
    await expectGoldensInThemes(
      tester,
      'ayah_row',
      (context) => SizedBox(
        width: 360,
        child: goldenColumn([
          AyahRow(
            number: 5,
            text: _text,
            onPlay: () {},
            onBookmark: () {},
            onStudy: () {},
          ),
          AyahRow(number: 286, text: _text, onPlay: () {}),
        ]),
      ),
      surfaceSize: const Size(400, 400),
    );
  });
}
