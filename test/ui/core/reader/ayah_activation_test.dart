import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/reader/gesture_target.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/reader/reader_highlights.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import '../../../../testing/golden.dart';
import 'reader_fixture.dart';

const _width = 360.0;
const _height = 640.0;

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('ayah_activation');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  Widget reader(
    List<GestureTarget> taps, {
    ReaderHighlights highlights = ReaderHighlights.none,
  }) => goldenApp(
    ReadingTheme.paper,
    SizedBox(
      width: _width,
      height: _height,
      child: CustomScrollView(
        slivers: [
          InteractiveSurahSliver(
            text: fixture.surahs[longSurah]!,
            highlights: highlights,
            onTap: taps.add,
          ),
        ],
      ),
    ),
  );

  void setView(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(_width, _height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a screen reader activates a marker and gets that ayah', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    setView(tester);
    final taps = <GestureTarget>[];
    await tester.pumpWidget(reader(taps));
    tester.semantics.tap(find.semantics.byLabel('الآية ٢'));
    await tester.pump();
    expect(taps, [MarkerTarget(fixture.surahs[longSurah]!.addressOf(2))]);
    handle.dispose();
  });

  testWidgets('a screen reader activates the ayah text too', (tester) async {
    final handle = tester.ensureSemantics();
    setView(tester);
    final taps = <GestureTarget>[];
    await tester.pumpWidget(reader(taps));
    final text = fixture.surahs[longSurah]!.ayat[2].text.verbatim;
    tester.semantics.tap(find.semantics.byLabel(text));
    await tester.pump();
    expect(taps, [MarkerTarget(fixture.surahs[longSurah]!.addressOf(3))]);
    handle.dispose();
  });

  testWidgets('only the selected ayah has a selected marker, and says so', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    setView(tester);
    final selected = fixture.surahs[longSurah]!.addressOf(2);
    await tester.pumpWidget(
      reader(const [], highlights: ReaderHighlights(selectedAyah: selected)),
    );
    final markers = tester
        .widgetList<AyahMarker>(find.byType(AyahMarker))
        .toList();
    expect(markers.where((m) => m.selected).map((m) => m.number), [2]);
    expect(
      tester.getSemantics(find.bySemanticsLabel('الآية ٢')),
      matchesSemantics(
        label: 'الآية ٢',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('with no gestures the markers are not buttons', (tester) async {
    final handle = tester.ensureSemantics();
    setView(tester);
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        SizedBox(
          width: _width,
          height: _height,
          child: CustomScrollView(
            slivers: [InteractiveSurahSliver(text: fixture.surahs[1]!)],
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('الآية ١').first),
      isNot(matchesSemantics(isButton: true)),
    );
    handle.dispose();
  });
}
