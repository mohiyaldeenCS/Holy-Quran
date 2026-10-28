import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/reader/pinch_step.dart';
import 'package:holyquran/ui/core/reader/reader_pinch_stepper.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';

import '../../../../testing/golden.dart';
import 'reader_fixture.dart';

const _portrait = Size(360, 640);
const _landscape = Size(640, 360);

/// Where the fingers meet in the viewport, and how far apart they start:
/// wide enough that the pinches below pass the scale slop.
const _fingers = Offset(180, 300);
const _spread = 200.0;

/// A reader as its screen would wire it: the step is the host's, the plan
/// comes back from the sliver's `onLayout`.
final class _Host extends StatefulWidget {
  const _Host({
    required this.text,
    required this.controller,
    required this.steps,
    required this.firstStep,
  });

  final SurahText text;
  final ScrollController controller;
  final List<int> steps;
  final int firstStep;

  @override
  State<_Host> createState() => _HostState();
}

final class _HostState extends State<_Host> {
  late int step = widget.firstStep;
  SurahLayout? layout;

  @override
  Widget build(BuildContext context) => ReaderPinchStepper(
    scrollController: widget.controller,
    layout: layout,
    step: step,
    onStep: (next) {
      widget.steps.add(next);
      setState(() => step = next);
    },
    child: SizedBox.expand(
      child: CustomScrollView(
        controller: widget.controller,
        slivers: [
          InteractiveSurahSliver(
            text: widget.text,
            step: readerTextSteps[step],
            onLayout: (next) => setState(() => layout = next),
          ),
        ],
      ),
    ),
  );
}

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('reader_pinch_stepper');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  late ScrollController controller;
  late List<int> steps;

  SurahLayout layoutOf(WidgetTester tester) {
    final layout = tester.state<_HostState>(find.byType(_Host)).layout;
    expect(layout, isNotNull);
    return layout!;
  }

  Future<SurahLayout> open(
    WidgetTester tester, {
    required int step,
    required double offset,
    Size size = _portrait,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    controller = ScrollController();
    addTearDown(controller.dispose);
    steps = [];
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        _Host(
          text: fixture.surahs[longSurah]!,
          controller: controller,
          steps: steps,
          firstStep: step,
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(offset);
    await tester.pumpAndSettle();
    return layoutOf(tester);
  }

  /// Two fingers [_spread] apart close or open to [scale] times that, about
  /// [_fingers], then lift.
  Future<void> pinch(WidgetTester tester, double scale) async {
    final left = await tester.startGesture(
      _fingers - const Offset(_spread / 2, 0),
    );
    final right = await tester.startGesture(
      _fingers + const Offset(_spread / 2, 0),
    );
    await tester.pump();
    final half = _spread * scale / 2;
    await left.moveTo(_fingers - Offset(half, 0));
    await right.moveTo(_fingers + Offset(half, 0));
    await tester.pump();
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
  }

  group('a pinch', () {
    testWidgets('out takes the step up and keeps the ayah in place', (
      tester,
    ) async {
      final before = await open(tester, step: 2, offset: 500);
      final focal = focalAyahOfLine(before, controller.offset + _fingers.dy);
      await pinch(tester, 1.3);
      expect(readerTextSteps[steps.single], 1.3);
      final after = layoutOf(tester);
      expect(after.lineHeight, greaterThan(before.lineHeight));
      final y = yOfFocalAyah(after, focal) - controller.offset;
      expect((y - _fingers.dy).abs(), lessThanOrEqualTo(after.lineHeight));
    });

    testWidgets('in takes the step down and keeps the ayah in place', (
      tester,
    ) async {
      final before = await open(tester, step: 4, offset: 900);
      final focal = focalAyahOfLine(before, controller.offset + _fingers.dy);
      await pinch(tester, 0.75);
      expect(steps.single, lessThan(4));
      final after = layoutOf(tester);
      expect(after.lineHeight, lessThan(before.lineHeight));
      final y = yOfFocalAyah(after, focal) - controller.offset;
      expect((y - _fingers.dy).abs(), lessThanOrEqualTo(after.lineHeight));
    });

    testWidgets('can move several steps and keeps the ayah in place', (
      tester,
    ) async {
      final before = await open(tester, step: 1, offset: 300);
      final focal = focalAyahOfLine(before, controller.offset + _fingers.dy);
      await pinch(tester, 1.8);
      expect(readerTextSteps[steps.single], 1.5);
      final after = layoutOf(tester);
      final y = yOfFocalAyah(after, focal) - controller.offset;
      expect((y - _fingers.dy).abs(), lessThanOrEqualTo(after.lineHeight));
    });

    testWidgets('stops at the largest step', (tester) async {
      final last = readerTextSteps.length - 1;
      await open(tester, step: last, offset: 500);
      final offset = controller.offset;
      await pinch(tester, 3);
      expect(steps, isEmpty);
      expect(controller.offset, offset);
    });

    testWidgets('stops at the smallest step', (tester) async {
      await open(tester, step: 0, offset: 500);
      final offset = controller.offset;
      await pinch(tester, 0.3);
      expect(steps, isEmpty);
      expect(controller.offset, offset);
    });
  });

  testWidgets('turning the device keeps the first ayah showing', (
    tester,
  ) async {
    final portrait = await open(tester, step: 2, offset: 700);
    final first = portrait.ayahAt(controller.offset);
    tester.view.physicalSize = _landscape;
    await tester.pumpAndSettle();
    final landscape = layoutOf(tester);
    expect(landscape.width, isNot(portrait.width));
    expect(landscape.ayahAt(controller.offset), first);
    tester.view.physicalSize = _portrait;
    await tester.pumpAndSettle();
    expect(layoutOf(tester).ayahAt(controller.offset), first);
  });

  testWidgets('a reader at the top of the text stays at the top when turned', (
    tester,
  ) async {
    await open(tester, step: 2, offset: 0);
    tester.view.physicalSize = _landscape;
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });
}
