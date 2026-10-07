@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/mark.dart';

import '../../../../testing/golden.dart';

// Each stroke step and both dot radii: 24 has no dot.
const _sizes = [24.0, 32.0, 48.0, 64.0, 96.0];

// The emerald and dark variants are drawn on the surfaces they are made for.
Color? _backdrop(MarkVariant variant) => switch (variant) {
  MarkVariant.emerald => Ramps.emerald700,
  MarkVariant.dark => Ramps.emerald950,
  MarkVariant.paper || MarkVariant.mono => null,
};

void main() {
  testWidgets('Mark variants at every stroke step', (tester) async {
    await expectGoldensInThemes(
      tester,
      'mark',
      (context) => goldenColumn([
        for (final variant in MarkVariant.values)
          ColoredBox(
            color: _backdrop(variant) ?? context.colors.ground,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: AppSpacing.space4,
                children: [
                  for (final size in _sizes) Mark(size: size, variant: variant),
                ],
              ),
            ),
          ),
      ]),
      surfaceSize: const Size(420, 560),
    );
  });
}
