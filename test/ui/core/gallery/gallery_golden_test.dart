@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/gallery/gallery_screen.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('the gallery block of each theme', (tester) async {
    // Taller than one block, so the whole block is in the image.
    tester.view
      ..physicalSize = const Size(400, 2700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const root = ValueKey('golden-root');
    for (final theme in ReadingTheme.values) {
      await tester.pumpWidget(
        goldenApp(theme, GalleryThemeBlock(theme: theme), key: root),
      );
      await expectLater(
        find.byKey(root),
        matchesGoldenFile('goldens/gallery_${theme.name}.png'),
      );
    }
  });
}
