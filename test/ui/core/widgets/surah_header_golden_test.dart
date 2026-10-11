@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/widgets/surah_header.dart';

import '../../../../testing/golden.dart';

// Synthetic name and information line.
const _name = PackText.fromPack('اسم تجريبي');
const _info = 'سطر تجريبي · ٧ آيات';

void main() {
  testWidgets('SurahHeader sizes, with and without information', (
    tester,
  ) async {
    await expectGoldensInThemes(
      tester,
      'surah_header',
      (context) => SizedBox(
        width: 360,
        child: goldenColumn(const [
          SurahHeader(name: _name),
          SurahHeader(name: _name, info: _info),
          SurahHeader(name: _name, size: SurahHeaderSize.lg, info: _info),
        ]),
      ),
      surfaceSize: const Size(400, 340),
    );
  });
}
