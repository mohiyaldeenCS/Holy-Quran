import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';

import '../s1/render/page_blocks_v2.dart';
import '../s1/render/spike_surah_text.dart';
import '../s1/render/surah_list_v1.dart';
import '../s1/render/surah_text_block.dart';
import '../s1/render/synthetic_surah_pack.dart';
import 'gesture_target.dart';
import 'reader_gestures.dart';
import 'tap_resolver.dart';
import 'target_geometry.dart';

// Every text is Arabic-script nonsense with marks from the spike writer's
// pack (D-083), read through the app's verification and text repository.

const _width = 360.0;
const _height = 800.0;
const _scrolled = 200.0;

SpikeSurahText _first(SpikeSurahText surah, int ayat) => SpikeSurahText(
  firstAyah: surah.firstAyah,
  ayat: surah.ayat.sublist(0, ayat),
  words: surah.words.sublist(0, ayat),
  marks: surah.marks.sublist(0, ayat),
  basmala: surah.basmala,
  pageStarts: {
    for (final MapEntry(:key, :value) in surah.pageStarts.entries)
      if (key.ayah <= ayat) key: value,
  },
);

/// What the reader under test reported.
final class _Log {
  final taps = <GestureTarget>[];
  final longPresses = <GestureTarget>[];
  final pinches = <(double, Offset)>[];
}

Future<void> _pump(WidgetTester tester, Widget list) async {
  tester.view
    ..physicalSize = const Size(_width, _height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(ReadingTheme.paper),
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
      home: Material(child: list),
    ),
  );
}

BlockWrapper _wrap(_Log log, {TapRule rule = TapRule.exact}) =>
    (context, block) => BlockGestures(
      rule: rule,
      onTap: log.taps.add,
      onLongPress: log.longPresses.add,
      child: block,
    );

Widget _pinch(_Log log, Widget child) => ReaderPinch(
  onPinchEnd: (scale, focal) => log.pinches.add((scale, focal)),
  child: child,
);

RenderSurahTextBlock _block(WidgetTester tester, [Finder? finder]) => tester
    .renderObject<RenderSurahTextBlock>(finder ?? find.byType(SurahTextBlock));

void main() {
  late Directory root;
  late SpikeSurahText surah;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('s7_gestures');
    final read = await readSyntheticSurahs(root, withMarks: true);
    surah = _first(read.long, 60);
    read.pack.close();
  });
  tearDownAll(() => root.delete(recursive: true));

  Future<(_Log, ScrollController)> pumpV1(
    WidgetTester tester, {
    TapRule rule = TapRule.exact,
  }) async {
    final log = _Log();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      _pinch(
        log,
        SurahListV1(
          surah: surah,
          controller: controller,
          wrapBlock: _wrap(log, rule: rule),
        ),
      ),
    );
    return (log, controller);
  }

  /// A word, a mark and a marker drawn inside the viewport, and a point on
  /// the basmala, in global coordinates, with the targets they are.
  List<(Offset, GestureTarget)> targetsOnScreen(WidgetTester tester) {
    final block = _block(tester);
    final origin = tester.getTopLeft(find.byType(SurahTextBlock));
    final g = TargetGeometry.of(block.paragraph);
    bool onScreen(Rect r) => r.shift(origin).bottom < _height - 10;
    final word = g.words.entries.firstWhere(
      (e) => e.value.single.width > 0 && onScreen(e.value.single),
    );
    final mark = g.marks.entries.firstWhere((e) => onScreen(e.value));
    final marker = g.markers.entries.firstWhere((e) => onScreen(e.value));
    return [
      (origin + word.value.single.center, WordTarget(word.key)),
      (origin + mark.value.center, WaqfMarkTarget(mark.key.$1, mark.key.$2)),
      (origin + marker.value.center, MarkerTarget(marker.key)),
      (
        origin + Offset(_width / 2, block.paragraph.bodyTop / 2),
        const MarginTarget(),
      ),
    ];
  }

  testWidgets('each kind of tap gives its target on the up, with no time '
      'pumped after it', (tester) async {
    final (log, _) = await pumpV1(tester);
    final targets = targetsOnScreen(tester);
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

  testWidgets('the zones rule takes a tap beside a mark as the mark', (
    tester,
  ) async {
    final (log, _) = await pumpV1(tester, rule: TapRule.priorityZones);
    final block = _block(tester);
    final origin = tester.getTopLeft(find.byType(SurahTextBlock));
    final g = TargetGeometry.of(block.paragraph);
    final mark = g.marks.entries.firstWhere(
      (e) => e.value.shift(origin).bottom < _height - 10 && e.value.width < 40,
    );
    await tester.tapAt(origin + mark.value.centerRight.translate(4, 0));
    expect(log.taps, [WaqfMarkTarget(mark.key.$1, mark.key.$2)]);
  });

  testWidgets('there is no double-tap recogniser, and taps 100 ms apart are '
      'two taps', (tester) async {
    final (log, _) = await pumpV1(tester);
    for (final detector in tester.widgetList<RawGestureDetector>(
      find.byType(RawGestureDetector),
    )) {
      expect(
        detector.gestures.keys,
        isNot(contains(DoubleTapGestureRecognizer)),
      );
    }
    final (point, target) = targetsOnScreen(tester).first;
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(point);
    expect(log.taps, [target, target]);
  });

  testWidgets('a long press fires at 500 ms, not 499, and its release is no '
      'tap', (tester) async {
    final (log, _) = await pumpV1(tester);
    for (final (point, target) in targetsOnScreen(tester)) {
      log.longPresses.clear();
      final gesture = await tester.startGesture(point);
      await tester.pump(const Duration(milliseconds: 499));
      expect(log.longPresses, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(log.longPresses, [target]);
      await gesture.up();
      await tester.pump();
    }
    expect(log.taps, isEmpty);
  });

  testWidgets('a 17 px slide is a tap; 19 px scrolls and is no tap', (
    tester,
  ) async {
    final (log, controller) = await pumpV1(tester);
    final (point, target) = targetsOnScreen(tester).first;
    var gesture = await tester.startGesture(point);
    await gesture.moveBy(const Offset(0, -17));
    expect(controller.position.isScrollingNotifier.value, isFalse);
    await gesture.up();
    expect(log.taps, [target]);
    expect(controller.offset, 0);
    await tester.pump();

    gesture = await tester.startGesture(point);
    await gesture.moveBy(const Offset(0, -19));
    expect(controller.position.isScrollingNotifier.value, isTrue);
    await gesture.moveBy(const Offset(0, -30));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(log.taps, [target]);
    expect(controller.offset, greaterThanOrEqualTo(30));
  });

  testWidgets('a tap during a fling opens nothing and stops the list', (
    tester,
  ) async {
    final (log, controller) = await pumpV1(tester);
    await tester.flingFrom(const Offset(180, 600), const Offset(0, -300), 3000);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final moving = controller.offset;
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.offset, greaterThan(moving), reason: 'still flinging');
    await tester.tapAt(const Offset(_width / 2, _height / 2));
    final stopped = controller.offset;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.offset, stopped);
    expect(log.taps, isEmpty);
    expect(log.longPresses, isEmpty);
  });

  Future<void> pinch(
    WidgetTester tester,
    Offset a,
    Offset b, {
    required bool outward,
  }) async {
    final first = await tester.startGesture(a, pointer: 7);
    final second = await tester.startGesture(b, pointer: 8);
    final away = a.dy < b.dy ? -1.0 : 1.0;
    final step = Offset(0, (outward ? 5 : -5) * away);
    for (var i = 0; i < 10; i++) {
      await first.moveBy(step);
      await tester.pump(const Duration(milliseconds: 16));
      await second.moveBy(-step);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await first.up();
    await second.up();
    await tester.pump();
  }

  testWidgets('a pinch in alternating 5 px steps is reported once, out as '
      'more than 1 and in as less, with no scroll and no tap', (tester) async {
    final (log, controller) = await pumpV1(tester);
    await pinch(
      tester,
      const Offset(180, 300),
      const Offset(180, 420),
      outward: true,
    );
    expect(log.pinches, hasLength(1));
    final (outScale, outFocal) = log.pinches.single;
    expect(outScale, greaterThan(1));
    expect(outFocal.dx, 180);
    expect(outFocal.dy, closeTo(360, 5));
    await pinch(
      tester,
      const Offset(180, 300),
      const Offset(180, 420),
      outward: false,
    );
    expect(log.pinches, hasLength(2));
    expect(log.pinches.last.$1, lessThan(1));
    expect(controller.offset, 0);
    expect(log.taps, isEmpty);
    expect(log.longPresses, isEmpty);
  });

  /// Two fingers down at [a] and [b], then ten rounds of steps [stepA] and
  /// [stepB], each followed by a frame, and both up.
  Future<void> unevenPinch(
    WidgetTester tester,
    Offset a,
    Offset b, {
    required Offset stepA,
    required Offset stepB,
  }) async {
    final first = await tester.startGesture(a, pointer: 7);
    final second = await tester.startGesture(b, pointer: 8);
    for (var i = 0; i < 10; i++) {
      if (stepA != Offset.zero) {
        await first.moveBy(stepA);
        await tester.pump(const Duration(milliseconds: 16));
      }
      if (stepB != Offset.zero) {
        await second.moveBy(stepB);
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    await first.up();
    await second.up();
    await tester.pump();
  }

  /// The V1 list scrolled to [_scrolled], so that a scroll either way
  /// would show.
  Future<(_Log, ScrollController)> pumpScrolled(WidgetTester tester) async {
    final (log, controller) = await pumpV1(tester);
    controller.jumpTo(_scrolled);
    await tester.pump();
    return (log, controller);
  }

  void expectOnePinch(
    _Log log,
    ScrollController controller, {
    required bool outward,
    String? reason,
  }) {
    expect(log.pinches, hasLength(1), reason: reason);
    expect(
      log.pinches.single.$1,
      outward ? greaterThan(1) : lessThan(1),
      reason: reason,
    );
    expect(controller.offset, _scrolled, reason: reason);
    expect(log.taps, isEmpty, reason: reason);
    expect(log.longPresses, isEmpty, reason: reason);
  }

  for (final gap in [120.0, 300.0, 500.0]) {
    testWidgets('a pinch with one finger still and the other moving 50 px in '
        '5 px steps, ${gap.toInt()} px apart, is one pinch, with no scroll '
        'and no tap', (tester) async {
      for (final outward in [true, false]) {
        final (log, controller) = await pumpScrolled(tester);
        await unevenPinch(
          tester,
          const Offset(180, 150),
          Offset(180, 150 + gap),
          stepA: Offset.zero,
          stepB: Offset(0, outward ? 5 : -5),
        );
        expectOnePinch(
          log,
          controller,
          outward: outward,
          reason: outward ? 'out' : 'in',
        );
      }
    });
  }

  testWidgets('a pinch whose fingers travel 1:4 is one pinch, with no scroll '
      'and no tap', (tester) async {
    for (final outward in [true, false]) {
      final (log, controller) = await pumpScrolled(tester);
      final sign = outward ? 1.0 : -1.0;
      await unevenPinch(
        tester,
        const Offset(180, 300),
        const Offset(180, 500),
        stepA: Offset(0, -1.25 * sign),
        stepB: Offset(0, 5 * sign),
      );
      expectOnePinch(
        log,
        controller,
        outward: outward,
        reason: outward ? 'out' : 'in',
      );
    }
  });

  testWidgets('a diagonal pinch with one finger still is one pinch, with no '
      'scroll and no tap', (tester) async {
    for (final outward in [true, false]) {
      final (log, controller) = await pumpScrolled(tester);
      final sign = outward ? 1.0 : -1.0;
      await unevenPinch(
        tester,
        const Offset(100, 250),
        const Offset(250, 450),
        stepA: Offset.zero,
        stepB: Offset(3 * sign, 4 * sign),
      );
      expectOnePinch(
        log,
        controller,
        outward: outward,
        reason: outward ? 'out' : 'in',
      );
    }
  });

  testWidgets('two fingers whose span changes by less than the scale slop '
      'report nothing; past it, one pinch', (tester) async {
    for (final (steps, reported) in [(17, 0), (19, 1)]) {
      final (log, controller) = await pumpScrolled(tester);
      await unevenPinch(
        tester,
        const Offset(180, 300),
        const Offset(180, 340),
        stepA: Offset.zero,
        stepB: Offset(0, steps * 2 / 10),
      );
      // Two fingers: the span is half the gap, which grew by 2 * steps.
      expect(log.pinches, hasLength(reported), reason: '$steps');
      expect(controller.offset, _scrolled);
      expect(log.taps, isEmpty);
      expect(log.longPresses, isEmpty);
    }
  });

  testWidgets('a third finger ends the pinch: three fingers give one report, '
      'and the next pinch is reported again', (tester) async {
    final (log, controller) = await pumpV1(tester);
    final first = await tester.startGesture(const Offset(180, 300), pointer: 7);
    final second = await tester.startGesture(
      const Offset(180, 420),
      pointer: 8,
    );
    Future<void> spread(TestGesture a, TestGesture b) async {
      for (var i = 0; i < 5; i++) {
        await a.moveBy(const Offset(0, -5));
        await tester.pump(const Duration(milliseconds: 16));
        await b.moveBy(const Offset(0, 5));
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await spread(first, second);
    final third = await tester.startGesture(const Offset(80, 360), pointer: 9);
    await tester.pump();
    expect(log.pinches, hasLength(1), reason: 'ended by the third finger');
    expect(log.pinches.single.$1, greaterThan(1));
    await spread(first, second);
    await third.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 16));
    await second.up();
    await tester.pump();
    await spread(first, third);
    await first.up();
    await third.up();
    await tester.pump();
    expect(log.pinches, hasLength(1));
    expect(controller.offset, 0);
    expect(log.taps, isEmpty);
    expect(log.longPresses, isEmpty);

    await pinch(
      tester,
      const Offset(180, 300),
      const Offset(180, 420),
      outward: false,
    );
    expect(log.pinches, hasLength(2));
    expect(log.pinches.last.$1, lessThan(1));
  });

  testWidgets('a pinch across two V2 blocks is reported once, with no scroll '
      'and no tap', (tester) async {
    final log = _Log();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      _pinch(
        log,
        PageBlocksV2(
          surah: surah,
          controller: controller,
          wrapBlock: _wrap(log),
          blockKey: (k) => ValueKey('block $k'),
        ),
      ),
    );
    final bottom = tester
        .getBottomLeft(find.byKey(const ValueKey('block 0')))
        .dy;
    controller.jumpTo(bottom - _height / 2);
    await tester.pump();
    final edge = tester.getBottomLeft(find.byKey(const ValueKey('block 0'))).dy;
    expect(edge, _height / 2);
    expect(find.byKey(const ValueKey('block 1')), findsOne);
    final scrolled = controller.offset;
    await pinch(
      tester,
      Offset(180, edge - 50),
      Offset(180, edge + 50),
      outward: true,
    );
    expect(log.pinches, hasLength(1));
    expect(log.pinches.single.$1, greaterThan(1));
    expect(controller.offset, scrolled);
    expect(log.taps, isEmpty);
    expect(log.longPresses, isEmpty);
  });

  testWidgets('a one-finger 200 px drag scrolls and is no pinch', (
    tester,
  ) async {
    final (log, controller) = await pumpV1(tester);
    await tester.dragFrom(const Offset(180, 600), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(150));
    expect(log.pinches, isEmpty);
    expect(log.taps, isEmpty);
    expect(log.longPresses, isEmpty);
  });
}
