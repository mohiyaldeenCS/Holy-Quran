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
}
