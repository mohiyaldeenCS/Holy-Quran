import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';

import '../../../../testing/golden.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget toolbar, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) {
  tester.view
    ..physicalSize = const Size(360, 640)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: toolbar,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('offers the five actions, each by its word, and runs them', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final pressed = <String>[];
    await _pump(
      tester,
      AyahToolbar(
        onPlay: () => pressed.add('play'),
        onBookmark: () => pressed.add('bookmark'),
        onStudy: () => pressed.add('study'),
        onCopy: () => pressed.add('copy'),
        onShare: () => pressed.add('share'),
      ),
    );
    for (final (label, id) in [
      ('تشغيل', 'play'),
      ('علامة', 'bookmark'),
      ('دراسة', 'study'),
      ('نسخ', 'copy'),
      ('مشاركة', 'share'),
    ]) {
      final finder = find.bySemanticsLabel(label);
      expect(finder, findsOneWidget, reason: label);
      expect(
        tester.getSize(finder).shortestSide,
        greaterThanOrEqualTo(48),
        reason: label,
      );
      await tester.tap(finder);
      expect(pressed.last, id);
    }
    handle.dispose();
  });

  testWidgets('leaves out an action with no callback', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, AyahToolbar(onBookmark: () {}));
    expect(find.bySemanticsLabel('علامة'), findsOneWidget);
    for (final label in ['تشغيل', 'دراسة', 'نسخ', 'مشاركة', 'تراجع']) {
      expect(find.bySemanticsLabel(label), findsNothing, reason: label);
    }
    handle.dispose();
  });

  testWidgets('says to a screen reader that the ayah is bookmarked', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, AyahToolbar(onBookmark: () {}, bookmarked: true));
    final node = tester.getSemantics(find.bySemanticsLabel('علامة'));
    expect(node.getSemanticsData().flagsCollection.isSelected.name, 'isTrue');
    await _pump(tester, AyahToolbar(onBookmark: () {}));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('علامة'))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .name,
      'isFalse',
    );
    handle.dispose();
  });

  testWidgets('says a notice above the toolbar, as a live region', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, AyahToolbar(onBookmark: () {}, notice: 'نص تجريبي'));
    expect(find.text('نص تجريبي'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.text('نص تجريبي'))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    expect(
      tester.getTopLeft(find.text('نص تجريبي')).dy,
      lessThan(tester.getTopLeft(find.bySemanticsLabel('علامة')).dy),
    );
    handle.dispose();
  });

  testWidgets('adds the undo word while it is given', (tester) async {
    final handle = tester.ensureSemantics();
    var undone = false;
    await _pump(
      tester,
      AyahToolbar(onBookmark: () {}, onUndo: () => undone = true),
    );
    await tester.tap(find.bySemanticsLabel('تراجع'));
    expect(undone, isTrue);
    handle.dispose();
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('fits 360 wide in ${theme.name} at 200% text', (tester) async {
      await _pump(
        tester,
        AyahToolbar(
          onPlay: () {},
          onBookmark: () {},
          bookmarked: true,
          onStudy: () {},
          onCopy: () {},
          onShare: () {},
        ),
        theme: theme,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AyahToolbar)).width, lessThan(360));
    });
  }
}
