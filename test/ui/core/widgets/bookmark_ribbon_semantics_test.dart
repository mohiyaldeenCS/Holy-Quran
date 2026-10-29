import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/widgets/bookmark_ribbon.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('is drawn 30 by 40 and read as a bookmark of its category', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        const BookmarkRibbon(
          shape: TagShape.ring,
          label: 'bookmark',
          category: 'category',
        ),
      ),
    );
    expect(tester.getSize(find.byType(BookmarkRibbon)), const Size(30, 40));
    final node = tester.getSemantics(find.bySemanticsLabel('bookmark'));
    expect(node.value, 'category');
    expect(node.getSemanticsData().flagsCollection.isImage, isTrue);
    handle.dispose();
  });

  Finder paintOf(WidgetTester tester) => find.descendant(
    of: find.byType(BookmarkRibbon),
    matching: find.byType(CustomPaint),
  );

  testWidgets('a ribbon with no category is a bare ribbon, read as a '
      'bookmark and nothing more', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        const BookmarkRibbon(shape: null, label: 'bookmark', category: null),
      ),
    );
    final node = tester.getSemantics(find.bySemanticsLabel('bookmark'));
    expect(node.value, isEmpty);
    // The ribbon alone: no circle, rounded square or ring, no second path.
    final paint = tester.renderObject(paintOf(tester).first);
    expect(paint, paintsExactlyCountTimes(#drawPath, 1));
    expect(paint, paintsExactlyCountTimes(#drawCircle, 0));
    expect(paint, paintsExactlyCountTimes(#drawRRect, 0));
    handle.dispose();
  });

  testWidgets('a ribbon with a category has its mark', (tester) async {
    for (final (shape, path, circle, rrect) in [
      (TagShape.diamond, 2, 0, 0),
      (TagShape.circle, 1, 1, 0),
      (TagShape.ring, 1, 1, 0),
      (TagShape.square, 1, 0, 1),
    ]) {
      await tester.pumpWidget(
        goldenApp(
          ReadingTheme.paper,
          BookmarkRibbon(shape: shape, label: 'bookmark', category: 'c'),
        ),
      );
      final paint = tester.renderObject(paintOf(tester).first);
      expect(paint, paintsExactlyCountTimes(#drawPath, path), reason: '$shape');
      expect(
        paint,
        paintsExactlyCountTimes(#drawCircle, circle),
        reason: '$shape',
      );
      expect(
        paint,
        paintsExactlyCountTimes(#drawRRect, rrect),
        reason: '$shape',
      );
    }
  });
}
