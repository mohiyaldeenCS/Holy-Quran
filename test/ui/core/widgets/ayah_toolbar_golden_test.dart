@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('the toolbar in the four themes', (tester) async {
    await expectGoldensInThemes(
      tester,
      'ayah_toolbar',
      (context) => goldenColumn([
        AyahToolbar(
          onPlay: () {},
          onBookmark: () {},
          onStudy: () {},
          onCopy: () {},
          onShare: () {},
        ),
        AyahToolbar(
          onPlay: () {},
          onBookmark: () {},
          bookmarked: true,
          onUndo: () {},
        ),
      ]),
      surfaceSize: const Size(360, 200),
    );
  });
}
