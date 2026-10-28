import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/gesture_target.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/reader/reader_pinch.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/reader/target_geometry.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

import '../../../../testing/golden.dart';
import 'reader_fixture.dart';

const _width = 360.0;
const _height = 640.0;

/// What the reader under test reported.
final class _Log {
  final taps = <GestureTarget>[];
  final longPresses = <GestureTarget>[];
  final pinches = <(double, Offset)>[];
}

Widget _reader(
  SurahText text,
  _Log log, {
  double systemScale = 1,
  ScrollController? controller,
  bool gestures = true,
  BlockOverlayBuilder? overlay,
}) => goldenApp(
  ReadingTheme.paper,
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(systemScale)),
      child: ReaderPinch(
        onPinchEnd: (scale, focal) => log.pinches.add((scale, focal)),
        child: SizedBox(
          width: _width,
          height: _height,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              InteractiveSurahSliver(
                text: text,
                onTap: gestures ? log.taps.add : null,
                onLongPress: gestures ? log.longPresses.add : null,
                blockOverlayBuilder: overlay,
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('interactive_sliver');
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

  BlockLayout firstBlock(WidgetTester tester) =>
      tester.widget<ReaderBlock>(find.byType(ReaderBlock).first).layout;

  /// A word, a mark and a marker on screen, as global points with the
  /// targets they are.
  List<(Offset, GestureTarget)> onScreen(WidgetTester tester) {
    final layout = firstBlock(tester);
    final origin = tester.getTopLeft(find.byType(ReaderBlock).first);
    final g = TargetGeometry.of(layout);
    bool shown(Rect r) => (origin + r.center).dy < _height - 20;
    final word = g.words.entries.firstWhere((e) => shown(e.value));
    final mark = g.marks.entries.firstWhere((e) => shown(e.value));
    final marker = g.markers.entries.firstWhere((e) => shown(e.value));
    return [
      (origin + word.value.center, WordTarget(word.key)),
      (origin + mark.value.center, WaqfMarkTarget(mark.key.$1, mark.key.$2)),
      (origin + marker.value.center, MarkerTarget(marker.key)),
    ];
  }

  testWidgets('each kind of tap gives its target on the up, with no time '
      'pumped after it', (tester) async {
    setView(tester);
    final log = _Log();
    await tester.pumpWidget(_reader(fixture.surahs[longSurah]!, log));
    final targets = onScreen(tester);
    for (final (point, target) in targets) {
      final gesture = await tester.startGesture(point);
      await tester.pump(const Duration(milliseconds: 50));
      expect(log.taps, isNot(contains(target)), reason: 'not before the up');
      await gesture.up();
      expect(log.taps.last, target);
    }
    expect(log.taps, [for (final (_, target) in targets) target]);
    expect(log.longPresses, isEmpty);
    expect(log.pinches, isEmpty);
  });

  testWidgets('the marker widget is tapped as its marker', (tester) async {
    setView(tester);
    final log = _Log();
    final surah = fixture.surahs[longSurah]!;
    await tester.pumpWidget(_reader(surah, log));
    final marker = find.byType(AyahMarker).first;
    final number = tester.widget<AyahMarker>(marker).number;
    await tester.tap(marker);
    expect(log.taps, [MarkerTarget(surah.addressOf(number))]);
  });

  testWidgets('a long press gives its target once, and no tap', (tester) async {
    setView(tester);
    final log = _Log();
    await tester.pumpWidget(_reader(fixture.surahs[longSurah]!, log));
    final (point, target) = onScreen(tester).first;
    await tester.longPressAt(point);
    expect(log.longPresses, [target]);
    expect(log.taps, isEmpty);
  });

  testWidgets('the basmala gives the margin', (tester) async {
    setView(tester);
    final log = _Log();
    await tester.pumpWidget(_reader(fixture.surahs[longSurah]!, log));
    await tester.tap(find.byType(QuranText));
    expect(log.taps, [const MarginTarget()]);
  });

  testWidgets('taps resolve at 200% text too', (tester) async {
    setView(tester);
    final log = _Log();
    await tester.pumpWidget(
      _reader(fixture.surahs[longSurah]!, log, systemScale: 2),
    );
    final targets = onScreen(tester);
    for (final (point, _) in targets) {
      await tester.tapAt(point);
    }
    expect(log.taps, [for (final (_, target) in targets) target]);
  });

  testWidgets('dragging scrolls and reports no tap', (tester) async {
    setView(tester);
    final log = _Log();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _reader(fixture.surahs[longSurah]!, log, controller: controller),
    );
    final (point, _) = onScreen(tester).first;
    await tester.dragFrom(point, const Offset(0, -200));
    await tester.pump();
    expect(controller.offset, greaterThan(0));
    expect(log.taps, isEmpty);
    expect(log.longPresses, isEmpty);
  });

  testWidgets('without callbacks nothing is reported and scrolling works', (
    tester,
  ) async {
    setView(tester);
    final log = _Log();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _reader(
        fixture.surahs[longSurah]!,
        log,
        controller: controller,
        gestures: false,
      ),
    );
    await tester.tapAt(onScreen(tester).first.$1);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pump();
    expect(log.taps, isEmpty);
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('a pinch is reported once, with its scale and focal point', (
    tester,
  ) async {
    setView(tester);
    final log = _Log();
    await tester.pumpWidget(_reader(fixture.surahs[longSurah]!, log));
    final a = await tester.startGesture(const Offset(150, 300));
    final b = await tester.startGesture(const Offset(210, 300));
    await tester.pump();
    await a.moveTo(const Offset(100, 300));
    await b.moveTo(const Offset(260, 300));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pump();
    expect(log.pinches, hasLength(1));
    expect(log.pinches.single.$1, closeTo(160 / 60, 0.01));
    expect(log.pinches.single.$2, const Offset(180, 300));
    expect(log.taps, isEmpty);
  });

  testWidgets('a block gets the overlay, over the text and out of taps', (
    tester,
  ) async {
    setView(tester);
    final log = _Log();
    final layouts = <BlockLayout>[];
    const key = ValueKey('overlay');
    await tester.pumpWidget(
      _reader(
        fixture.surahs[longSurah]!,
        log,
        overlay: (context, layout) {
          layouts.add(layout);
          return const SizedBox(key: key);
        },
      ),
    );
    expect(find.byKey(key), findsWidgets);
    expect(layouts.map((l) => l.index), contains(0));
    expect(
      layouts.any((layout) => layout.marginMarks.isNotEmpty),
      isTrue,
      reason: 'the long surah has margin marks',
    );
    final (point, target) = onScreen(tester).first;
    await tester.tapAt(point);
    expect(log.taps, [target]);
  });
}
