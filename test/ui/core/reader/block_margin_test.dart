import 'dart:io';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/reader/block_margin.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/reader/margin_mark.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/widgets/bookmark_ribbon.dart';

import '../../../../testing/golden.dart';
import 'reader_fixture.dart';

const _width = 360.0;
const _height = 640.0;

Widget _reader(
  ReaderFixture fixture,
  Map<QuranAddress, BuiltinCategory?> bookmarks,
) => goldenApp(
  ReadingTheme.paper,
  SizedBox(
    width: _width,
    height: _height,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: CustomScrollView(
        slivers: [
          InteractiveSurahSliver(
            text: fixture.surahs[longSurah]!,
            blockOverlayBuilder: (context, layout) =>
                BlockMargin(layout: layout, bookmarks: bookmarks),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('block_margin');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  void setView(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(_width, _height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('margin marks stand over the start edge, level with their line', (
    tester,
  ) async {
    setView(tester);
    await tester.pumpWidget(_reader(fixture, const {}));
    final views = tester.widgetList<MarginMarkView>(
      find.byType(MarginMarkView),
    );
    expect(views, isNotEmpty);
    final first = find.byType(MarginMarkView).first;
    // RTL: the start edge is the right one, and the text column ends 28 px
    // inside the screen.
    expect(tester.getTopRight(first).dx, closeTo(_width, 0.5));
    final layout = tester
        .widget<ReaderBlock>(find.byType(ReaderBlock).first)
        .layout;
    final (mark, band) = layout.marginMarks.first;
    expect(views.first.mark, mark);
    final block = tester.getTopLeft(find.byType(ReaderBlock).first);
    expect(tester.getCenter(first).dy, closeTo(block.dy + band.center.dy, 0.5));
  });

  testWidgets('a bookmarked ayah gets its ribbon on the end side, once', (
    tester,
  ) async {
    setView(tester);
    final ayah = fixture.surahs[longSurah]!.addressOf(3);
    await tester.pumpWidget(_reader(fixture, {ayah: BuiltinCategory.review}));
    final ribbon = find.byType(BookmarkRibbon);
    expect(ribbon, findsOneWidget);
    expect(tester.getTopLeft(ribbon).dx, closeTo(0, 0.5));
    expect(tester.getSize(ribbon), BookmarkRibbon.size);
  });

  testWidgets('an ayah of another surah gets none', (tester) async {
    setView(tester);
    await tester.pumpWidget(
      _reader(fixture, {
        fixture.surahs[1]!.addressOf(1): BuiltinCategory.study,
      }),
    );
    expect(find.byType(BookmarkRibbon), findsNothing);
  });

  testWidgets('a screen reader meets the ribbon after its ayah, with the '
      'category', (tester) async {
    final handle = tester.ensureSemantics();
    setView(tester);
    final ayah = fixture.surahs[longSurah]!.addressOf(3);
    await tester.pumpWidget(_reader(fixture, {ayah: BuiltinCategory.memorise}));
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final labels = <String>[];
    void visit(SemanticsNode node) {
      if (node.label.isNotEmpty) {
        labels.add(
          node.value.isEmpty ? node.label : '${node.label}|${node.value}',
        );
      }
      node
          .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
          .forEach(visit);
    }

    visit(
      tester
          .renderObject(find.byType(CustomScrollView))
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!,
    );
    final ribbon = labels.indexOf(
      '${l10n.ayahRowBookmark}|${l10n.tagMemorise}',
    );
    expect(ribbon, isNonNegative);
    final marker = labels.indexOf(l10n.ayahMarkerLabel('٣'));
    final next = labels.indexOf(l10n.ayahMarkerLabel('٤'));
    expect(ribbon, greaterThan(marker));
    expect(ribbon, lessThan(next));
    handle.dispose();
  });

  testWidgets('a bookmark with no known category has a bare ribbon, announced '
      'as a bookmark with no category', (tester) async {
    final handle = tester.ensureSemantics();
    setView(tester);
    final ayah = fixture.surahs[longSurah]!.addressOf(3);
    await tester.pumpWidget(_reader(fixture, {ayah: null}));
    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(find.byType(BookmarkRibbon), findsOneWidget);
    final ribbon = tester.widget<BookmarkRibbon>(find.byType(BookmarkRibbon));
    expect(ribbon.shape, isNull);
    expect(ribbon.category, isNull);
    final node = tester.getSemantics(find.byType(BookmarkRibbon));
    expect(node.label, l10n.ayahRowBookmark);
    expect(node.value, isEmpty);
    handle.dispose();
  });
}
