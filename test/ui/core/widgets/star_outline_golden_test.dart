@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('StarOutline sizes, strokes and colour', (tester) async {
    await expectGoldensInThemes(
      tester,
      'star_outline',
      (context) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.space4,
        children: [
          const StarOutline(),
          const StarOutline(size: 32),
          const StarOutline(size: 44, stroke: 4),
          StarOutline(size: 44, color: context.colors.accent),
        ],
      ),
      surfaceSize: const Size(260, 80),
    );
  });
}
