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
import 'package:holyquran/ui/core/theme/tokens.g.dart';

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
    this.takesSteps = true,
    this.leading = 0,
  });

  final SurahText text;
  final ScrollController controller;
  final List<int> steps;
  final int firstStep;
  final bool takesSteps;
  final double leading;

  @override
  State<_Host> createState() => _HostState();
}

final class _HostState extends State<_Host> {
  late int step = widget.firstStep;
  final layout = ValueNotifier<SurahLayout?>(null);

  @override
  void dispose() {
    layout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ReaderPinchStepper(
    scrollController: widget.controller,
    layout: layout,
    step: step,
    leadingExtent: () => widget.leading,
    onStep: (next) {
      widget.steps.add(next);
      if (widget.takesSteps) setState(() => step = next);
    },
    child: SizedBox.expand(
      child: CustomScrollView(
        controller: widget.controller,
        slivers: [
          if (widget.leading > 0)
            SliverToBoxAdapter(child: SizedBox(height: widget.leading)),
          InteractiveSurahSliver(
            text: widget.text,
            step: readerTextSteps[step],
            onLayout: (next) => layout.value = next,
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
    final layout = tester.state<_HostState>(find.byType(_Host)).layout.value;
    expect(layout, isNotNull);
    return layout!;
  }

  Future<SurahLayout> open(
    WidgetTester tester, {
    required int step,
    required double offset,
    Size size = _portrait,
    bool takesSteps = true,
    double leading = 0,
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
          takesSteps: takesSteps,
          leading: leading,
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(offset);
    await tester.pumpAndSettle();
    return layoutOf(tester);
  }

  /// What every frame from now on painted: the host's step and the scroll
  /// offset when the frame was drawn.
  List<({int step, double offset})> recordFrames(WidgetTester tester) {
    final frames = <({int step, double offset})>[];
    final host = tester.state<_HostState>(find.byType(_Host));
    var recording = true;
    addTearDown(() => recording = false);
    tester.binding.addPersistentFrameCallback((_) {
      if (recording && controller.hasClients) {
        frames.add((step: host.step, offset: controller.offset));
      }
    });
    return frames;
  }

  FocalAyah underFingers(SurahLayout layout, {double leading = 0}) =>
      focalAyahUnder(
        layout,
        Offset(_fingers.dx, controller.offset - leading + _fingers.dy),
        ink: AppColors.paper.quranInk,
      );

  /// Two fingers [_spread] apart close or open to [scale] times that, about
  /// [_fingers], then lift.
  Future<void> pinch(
    WidgetTester tester,
    double scale, {
    Offset at = _fingers,
  }) async {
    final left = await tester.startGesture(at - const Offset(_spread / 2, 0));
    final right = await tester.startGesture(at + const Offset(_spread / 2, 0));
    await tester.pump();
    final half = _spread * scale / 2;
    await left.moveTo(at - Offset(half, 0));
    await right.moveTo(at + Offset(half, 0));
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
      final focal = underFingers(before);
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
      final focal = underFingers(before);
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
      final focal = underFingers(before);
      await pinch(tester, 1.8);
      expect(readerTextSteps[steps.single], 1.5);
      final after = layoutOf(tester);
      final y = yOfFocalAyah(after, focal) - controller.offset;
      expect((y - _fingers.dy).abs(), lessThanOrEqualTo(after.lineHeight));
    });

    testWidgets('shows the new size at the old offset for one frame at most', (
      tester,
    ) async {
      await open(tester, step: 2, offset: 500);
      final frames = recordFrames(tester);
      await pinch(tester, 1.3);
      final next = steps.single;
      final late = frames.where((f) => f.step == next && f.offset == 500);
      expect(late.length, lessThanOrEqualTo(1));
      expect(controller.offset, isNot(500));
      expect(frames.last.step, next);
    });

    testWidgets('on the basmala at the top leaves the view at the top', (
      tester,
    ) async {
      final before = await open(tester, step: 2, offset: 0);
      const onBasmala = Offset(180, 40);
      expect(before.basmalaExtent, greaterThan(onBasmala.dy));
      await pinch(tester, 1.3, at: onBasmala);
      expect(readerTextSteps[steps.single], 1.3);
      expect(layoutOf(tester).lineHeight, greaterThan(before.lineHeight));
      expect(controller.offset, 0);
    });

    testWidgets('keeps the ayah in place below a leading extent', (
      tester,
    ) async {
      const leading = 120.0;
      final before = await open(
        tester,
        step: 2,
        offset: leading + 500,
        leading: leading,
      );
      final focal = underFingers(before, leading: leading);
      await pinch(tester, 1.3);
      final after = layoutOf(tester);
      expect(after.lineHeight, greaterThan(before.lineHeight));
      final y = leading + yOfFocalAyah(after, focal) - controller.offset;
      expect((y - _fingers.dy).abs(), lessThanOrEqualTo(after.lineHeight));
    });

    testWidgets('on the leading extent at the top leaves the view there', (
      tester,
    ) async {
      await open(tester, step: 2, offset: 0, leading: 120);
      await pinch(tester, 1.3, at: const Offset(180, 40));
      expect(steps, hasLength(1));
      expect(controller.offset, 0);
    });

    testWidgets('in at the end of the surah stays at the end', (tester) async {
      final before = await open(tester, step: 4, offset: 0);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await pinch(tester, 0.75);
      expect(steps.single, lessThan(4));
      expect(layoutOf(tester).lineHeight, lessThan(before.lineHeight));
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(tester.takeException(), isNull);
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

  testWidgets('a pinch the screen ignored does not anchor a later turn', (
    tester,
  ) async {
    final portrait = await open(
      tester,
      step: 2,
      offset: 700,
      takesSteps: false,
    );
    final first = portrait.ayahAt(controller.offset);
    await pinch(tester, 1.3);
    expect(steps, hasLength(1));
    tester.view.physicalSize = _landscape;
    await tester.pumpAndSettle();
    expect(layoutOf(tester).ayahAt(controller.offset), first);
  });

  group('leaving the screen', () {
    testWidgets('mid-pinch reports nothing and throws nothing', (tester) async {
      await open(tester, step: 2, offset: 500);
      final left = await tester.startGesture(_fingers - const Offset(100, 0));
      final right = await tester.startGesture(_fingers + const Offset(100, 0));
      await tester.pump();
      await left.moveTo(_fingers - const Offset(130, 0));
      await right.moveTo(_fingers + const Offset(130, 0));
      await tester.pumpWidget(const SizedBox());
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      expect(steps, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('after a pinch, before the plan, restores nothing', (
      tester,
    ) async {
      await open(tester, step: 2, offset: 500);
      final left = await tester.startGesture(_fingers - const Offset(100, 0));
      final right = await tester.startGesture(_fingers + const Offset(100, 0));
      await tester.pump();
      await left.moveTo(_fingers - const Offset(130, 0));
      await right.moveTo(_fingers + const Offset(130, 0));
      await tester.pump();
      await left.up();
      await right.up();
      expect(steps, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(steps, hasLength(1));
      expect(tester.takeException(), isNull);
    });
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
