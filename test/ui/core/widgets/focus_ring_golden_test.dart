@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';

import '../../../../testing/golden.dart';

void main() {
  // expectGoldensInThemes compares the first frame, before autofocus has
  // landed, so this test pumps once more per theme with the same app and
  // file names.
  testWidgets('the keyboard focus ring in each theme', (tester) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    tester.view
      ..physicalSize = const Size(240, 120)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const root = ValueKey('golden-root');
    final radius = BorderRadius.circular(AppRadius.radiusButton);
    for (final theme in ReadingTheme.values) {
      await tester.pumpWidget(
        goldenApp(
          theme,
          Builder(
            builder: (context) => FocusRing(
              radius: radius,
              child: Focus(
                autofocus: true,
                child: Container(
                  width: 160,
                  height: AppSizes.buttonHeight,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          ),
          key: root,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byKey(root),
        matchesGoldenFile('goldens/focus_ring_${theme.name}.png'),
      );
    }
  });
}
