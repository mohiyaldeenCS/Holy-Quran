import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/page_mark.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/reader/surah_sliver.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

import '../../../../testing/golden.dart';
import 'reader_fixture.dart';

const _width = 360.0;
const _height = 640.0;

Widget _reader(
  SurahText text, {
  ReadingTheme theme = ReadingTheme.paper,
  double systemScale = 1,
  double step = 1,
  ScrollController? controller,
  ValueChanged<SurahLayout>? onLayout,
}) => goldenApp(
  theme,
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(systemScale)),
      child: SizedBox(
        width: _width,
        height: _height,
        child: CustomScrollView(
          controller: controller,
          slivers: [SurahSliver(text: text, step: step, onLayout: onLayout)],
        ),
      ),
    ),
  ),
);

/// Every semantics label on screen, in traversal order.
List<String> _labels(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(child);
    }
  }

  visit(
    tester
        .renderObject(find.byType(CustomScrollView))
        .owner!
        .semanticsOwner!
        .rootSemanticsNode!,
  );
  return labels;
}

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('surah_sliver');
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

  testWidgets('the basmala is its own line from the pack field', (
    tester,
  ) async {
    setView(tester);
    await tester.pumpWidget(_reader(fixture.surahs[longSurah]!));
    final basmala = tester.widget<QuranText>(find.byType(QuranText));
    expect(basmala.text, fixture.surahs[longSurah]!.basmala);
    expect(basmala.align, QuranTextAlign.center);
    for (final surah in [1, 9]) {
      await tester.pumpWidget(_reader(fixture.surahs[surah]!));
      expect(find.byType(QuranText), findsNothing, reason: 'surah $surah');
      expect(find.byType(AyahMarker), findsWidgets);
    }
  });

  testWidgets('screen readers read each ayah as stored, then its marker', (
    tester,
  ) async {
    setView(tester);
    final semantics = tester.ensureSemantics();
    final surah = fixture.surahs[overwideSurah]!;
    await tester.pumpWidget(_reader(surah));
    final strings = lookupAppLocalizations(const Locale('ar'));
    final labels = _labels(tester);
    var at = 0;
    for (final (ayah, bytes) in fixture.pack.raw.ayat(overwideSurah)) {
      final text = labels.indexOf(utf8.decode(bytes), at);
      expect(text, greaterThanOrEqualTo(at), reason: 'ayah $ayah');
      final marker = labels.indexOf(
        strings.ayahMarkerLabel(arabicDigits(ayah)),
        text,
      );
      expect(marker, greaterThan(text), reason: 'ayah $ayah');
      at = marker;
    }
    semantics.dispose();
  });

  testWidgets('a page mark is read as its page', (tester) async {
    setView(tester);
    final semantics = tester.ensureSemantics();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    late SurahLayout layout;
    final surah = fixture.surahs[longSurah]!;
    await tester.pumpWidget(
      _reader(surah, controller: controller, onLayout: (l) => layout = l),
    );
    await tester.pump();
    controller.jumpTo(layout.offsetOf(surah.addressOf(7)));
    await tester.pump();
    final strings = lookupAppLocalizations(const Locale('ar'));
    expect(find.byType(PageMark), findsWidgets);
    final labels = _labels(tester);
    final page = labels.indexOf(strings.pageLabel(arabicDigits(3)));
    final ayah = labels.indexOf(
      utf8.decode(fixture.pack.raw.ayat(longSurah)[6].$2),
    );
    expect(page, greaterThanOrEqualTo(0));
    expect(ayah, greaterThan(page));
    semantics.dispose();
  });

  testWidgets('jumping to an address shows it, and the position reads back', (
    tester,
  ) async {
    setView(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    SurahLayout? layout;
    final surah = fixture.surahs[longSurah]!;
    await tester.pumpWidget(
      _reader(surah, controller: controller, onLayout: (l) => layout = l),
    );
    await tester.pump();
    expect(layout, isNotNull);
    for (final ayah in [30, 12, longSurahAyat]) {
      final address = surah.addressOf(ayah);
      final offset = layout!.offsetOf(address);
      controller.jumpTo(offset.clamp(0, controller.position.maxScrollExtent));
      await tester.pump();
      final marker = find.byWidgetPredicate(
        (widget) => widget is AyahMarker && widget.number == ayah,
      );
      expect(marker, findsOneWidget);
      final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
      expect(tester.getRect(marker).bottom, greaterThan(top));
      if (controller.offset == offset) {
        expect(layout!.ayahAt(controller.offset).ayah, lessThanOrEqualTo(ayah));
      }
    }
    expect(controller.position.maxScrollExtent + _height, layout!.height);
  });

  testWidgets('scrolling does not rebuild the blocks on screen', (
    tester,
  ) async {
    setView(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _reader(fixture.surahs[longSurah]!, controller: controller),
    );
    final before = tester.widget<ReaderBlock>(find.byType(ReaderBlock).first);
    for (var k = 1; k <= 5; k++) {
      controller.jumpTo(3.0 * k);
      await tester.pump();
    }
    final after = tester.widget<ReaderBlock>(find.byType(ReaderBlock).first);
    expect(identical(before, after), isTrue);
  });

  testWidgets('at 200% text and the largest step nothing overflows', (
    tester,
  ) async {
    setView(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    for (final surah in fixture.surahs.values) {
      await tester.pumpWidget(
        _reader(surah, systemScale: 2, step: 2, controller: controller),
      );
      while (true) {
        expect(tester.takeException(), isNull);
        for (final element in find.byType(AyahMarker).evaluate()) {
          final rect = tester.getRect(find.byWidget(element.widget));
          expect(rect.left, greaterThanOrEqualTo(-0.5));
          expect(rect.right, lessThanOrEqualTo(_width + 0.5));
        }
        if (controller.offset >= controller.position.maxScrollExtent) break;
        controller.jumpTo(
          (controller.offset + _height / 2).clamp(
            0,
            controller.position.maxScrollExtent,
          ),
        );
        await tester.pump();
      }
      controller.jumpTo(0);
    }
  });

  testWidgets('the text is drawn in each theme\'s quran-ink', (tester) async {
    setView(tester);
    for (final theme in ReadingTheme.values) {
      await tester.pumpWidget(
        _reader(fixture.surahs[longSurah]!, theme: theme),
      );
      final context = tester.element(find.byType(ReaderBlock).first);
      final layout = tester.widget<ReaderBlock>(find.byType(ReaderBlock).first);
      expect(layout.layout.ink, context.colors.quranInk, reason: theme.name);
      expect(layout.layout, isA<BlockLayout>());
    }
  });
}
