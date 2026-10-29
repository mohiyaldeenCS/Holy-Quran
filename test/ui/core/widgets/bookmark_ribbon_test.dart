@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/bookmark_ribbon.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('the four ribbons in the four themes', (tester) async {
    await expectGoldensInThemes(
      tester,
      'bookmark_ribbon',
      (context) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.space4,
        children: [
          for (final shape in TagShape.values)
            BookmarkRibbon(shape: shape, label: 'a', category: 'b'),
        ],
      ),
      surfaceSize: const Size(240, 100),
    );
  });
}
