import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/theme/motion.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

import 'synthetic_pages.dart';

// S7's page-mode rows of PRD 7.4 on synthetic pages (D-095): drag turns with
// the next page on the left, pinch zoom 1 to 4 with pan (RD-07), pan before
// turn, the reduce-motion fade (AX-06, RD-11) and taps on lines or the
// margin. No Quran text: the pages are bars and a number.

const double _w = 360;
const double _h = 640;
const Size _view = Size(_w, _h);
const Offset _centre = Offset(_w / 2, _h / 2);

Duration _now = Duration.zero;

/// A later timestamp for each pointer event, so velocities are real.
Duration _tick([int ms = 16]) => _now += Duration(milliseconds: ms);

Future<List<PageGesture>> _pumpPages(
  WidgetTester tester, {
  int pageCount = 604,
  bool reduceMotion = false,
  ReadingTheme theme = ReadingTheme.paper,
  Key? key,
}) async {
  tester.view
    ..physicalSize = _view
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final gestures = <PageGesture>[];
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: _view, disableAnimations: reduceMotion),
      child: Theme(
        data: buildAppTheme(theme),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SyntheticPages(
            key: key,
            pageCount: pageCount,
            onGesture: gestures.add,
          ),
        ),
      ),
    ),
  );
  return gestures;
}

Finder _page(int index) => find.byWidgetPredicate(
  (widget) => widget is SyntheticPage && widget.index == index,
);

Rect _rect(WidgetTester tester, int index) => tester.getRect(_page(index));

int _built(WidgetTester tester) =>
    tester.widgetList(find.byType(SyntheticPage)).length;

Future<TestGesture> _down(WidgetTester tester, Offset at) async {
  final gesture = await tester.createGesture();
  await gesture.down(at, timeStamp: _tick());
  return gesture;
}

/// Moves [gesture] by [by]: 40 px first, which wins the arena and reports
/// its whole travel, then the rest in [steps] steps [stepMs] apart.
Future<void> _move(
  WidgetTester tester,
  TestGesture gesture,
  Offset by, {
  int steps = 6,
  int stepMs = 16,
}) async {
  var rest = by;
  if (by.distance > 40) {
    final first = by / by.distance * 40;
    await gesture.moveBy(first, timeStamp: _tick(stepMs));
    rest -= first;
  }
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(rest / steps.toDouble(), timeStamp: _tick(stepMs));
    await tester.pump();
  }
}

/// Moves [gesture] by [by] in four quick steps and lifts at once: a fling.
Future<void> _flick(WidgetTester tester, TestGesture gesture, Offset by) async {
  for (var i = 0; i < 4; i++) {
    await gesture.moveBy(by / 4, timeStamp: _tick(8));
    await tester.pump();
  }
  await gesture.up(timeStamp: _tick(1));
}

/// Holds still for [ms] and lifts: a release with no velocity.
Future<void> _holdAndLift(TestGesture gesture, {int ms = 100}) async {
  await gesture.moveBy(Offset.zero, timeStamp: _tick(ms));
  await gesture.up(timeStamp: _tick(1));
}

/// Two fingers about [focal], [from] to [to] from it horizontally, the pair
/// moving by [drift] on the way. The first finger wins the arena alone, 40 px
/// down and back, so the pinch's baseline is the span the second finger
/// lands at and the scale is exactly [to] / [from].
Future<void> _pinch(
  WidgetTester tester,
  Offset focal,
  double from,
  double to, {
  Offset drift = Offset.zero,
}) async {
  final a = await _down(tester, focal - Offset(from, 0));
  await a.moveBy(const Offset(0, 40), timeStamp: _tick());
  await a.moveBy(const Offset(0, -40), timeStamp: _tick());
  await tester.pump();
  final b = await _down(tester, focal + Offset(from, 0));
  const steps = 8;
  final spread = (to - from) / steps;
  final shift = drift / steps.toDouble();
  for (var i = 0; i < steps; i++) {
    await a.moveBy(shift - Offset(spread, 0), timeStamp: _tick());
    await b.moveBy(shift + Offset(spread, 0), timeStamp: _tick());
    await tester.pump();
  }
  await a.up(timeStamp: _tick());
  await b.up(timeStamp: _tick());
  await tester.pump();
}

/// Zoom exactly 2 about (180, 360), the page at (-180, -360): one finger
/// wins the arena with a vertical move that pans nothing at zoom 1, the
/// second lands 100 away and a still move starts the pinch there, and the
/// pair spreads from a span of 50 to 100.
Future<void> _zoomTo2(WidgetTester tester) async {
  final a = await _down(tester, const Offset(130, 320));
  await a.moveBy(const Offset(0, 40), timeStamp: _tick());
  await tester.pump();
  final b = await _down(tester, const Offset(230, 360));
  await a.moveBy(Offset.zero, timeStamp: _tick());
  await tester.pump();
  await a.moveBy(const Offset(-50, 0), timeStamp: _tick());
  await b.moveBy(const Offset(50, 0), timeStamp: _tick());
  await tester.pump();
  await a.up(timeStamp: _tick());
  await b.up(timeStamp: _tick());
  await tester.pump();
}

Matcher _rectNear(Rect expected) => isA<Rect>()
    .having((r) => r.left, 'left', moreOrLessEquals(expected.left))
    .having((r) => r.top, 'top', moreOrLessEquals(expected.top))
    .having((r) => r.right, 'right', moreOrLessEquals(expected.right))
    .having((r) => r.bottom, 'bottom', moreOrLessEquals(expected.bottom));

Matcher _turn({required int to, double zoom = 1, bool fade = false}) =>
    isA<PageTurn>()
        .having((g) => g.to, 'to', to)
        .having((g) => g.zoom, 'zoom', zoom)
        .having((g) => g.fade, 'fade', fade);

void main() {
  group('pure geometry', () {
    test('fifteen centred bars and a number band, inset by space-5', () {
      for (final size in const [Size(360, 640), Size(412, 915)]) {
        final layout = syntheticPageLayout(size);
        const inset = AppSpacing.space5;
        final band = (size.height - 2 * inset) / 16;
        final em = band / 2.3;
        expect(layout.lines, hasLength(15));
        expect(layout.rules, hasLength(15));
        for (final (i, line) in layout.lines.indexed) {
          expect(line.left, inset);
          expect(line.right, moreOrLessEquals(size.width - inset));
          expect(line.height, moreOrLessEquals(0.62 * em));
          expect(
            layout.rules[i],
            _rectNear(
              Rect.fromLTWH(line.left, line.bottom + 0.05 * em, line.width, 2),
            ),
          );
          expect(
            line.center.dy,
            moreOrLessEquals(inset + band * (i + 0.5)),
            reason: 'line ${i + 1} of $size',
          );
        }
        expect(
          layout.number,
          _rectNear(
            Rect.fromLTWH(
              inset,
              inset + band * 15,
              size.width - 2 * inset,
              band,
            ),
          ),
        );
      }
    });

    test('zoom is clamped to 1..4', () {
      expect(clampPageZoom(0.5), 1);
      expect(clampPageZoom(2), 2);
      expect(clampPageZoom(9), 4);
    });

    test('the pan keeps the page covering the pager', () {
      expect(clampPagePan(const Offset(10, 10), 2, _view), Offset.zero);
      expect(
        clampPagePan(const Offset(-1000, -1000), 2, _view),
        const Offset(-360, -640),
      );
      expect(clampPagePan(const Offset(-50, 30), 1, _view), Offset.zero);
    });

    test('travel pans first, turns with the rest, within the pages', () {
      ({double pan, double turn}) split(
        double x,
        double zoom, {
        bool hasPrevious = true,
        bool hasNext = true,
      }) => splitDrag(
        x,
        zoom: zoom,
        width: _w,
        hasPrevious: hasPrevious,
        hasNext: hasNext,
      );

      expect(split(100, 1), (pan: 0.0, turn: 100.0));
      expect(split(-100, 1), (pan: 0.0, turn: -100.0));
      expect(split(500, 1), (pan: 0.0, turn: 360.0));
      expect(split(-500, 1), (pan: 0.0, turn: -360.0));
      // The first page has no previous; the last, no next.
      expect(split(-100, 1, hasPrevious: false), (pan: 0.0, turn: 0.0));
      expect(split(100, 1, hasPrevious: false), (pan: 0.0, turn: 100.0));
      expect(split(100, 1, hasNext: false), (pan: 0.0, turn: 0.0));
      expect(split(-100, 1, hasNext: false), (pan: 0.0, turn: -100.0));

      expect(split(-200, 2), (pan: -200.0, turn: 0.0));
      expect(split(-500, 2), (pan: -360.0, turn: -140.0));
      expect(split(100, 2), (pan: 0.0, turn: 100.0));
      expect(split(-500, 2, hasPrevious: false), (pan: -360.0, turn: 0.0));
      expect(split(100, 2, hasNext: false), (pan: 0.0, turn: 0.0));
    });
  });

  group('turning, right to left', () {
    testWidgets('a rightward drag brings the next page in from the left', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      expect(_built(tester), 1);

      final drag = await _down(tester, _centre);
      await _move(tester, drag, const Offset(0.6 * _w, 0));
      expect(_built(tester), 2);
      expect(_rect(tester, 1).left, moreOrLessEquals(0.6 * _w - _w));
      expect(_rect(tester, 0).left, moreOrLessEquals(0.6 * _w));
      await drag.up(timeStamp: _tick());
      await tester.pump();
      expect(_built(tester), lessThanOrEqualTo(2));
      await tester.pumpAndSettle();
      expect(_built(tester), 1);
      expect(_rect(tester, 1), _rectNear(Offset.zero & _view));
      expect(gestures, [_turn(to: 1)]);
      expect(gestures.single.page, 0);

      final back = await _down(tester, _centre);
      await _move(tester, back, const Offset(-0.6 * _w, 0));
      expect(_built(tester), 2);
      expect(_rect(tester, 0).left, moreOrLessEquals(_w - 0.6 * _w));
      await back.up(timeStamp: _tick());
      await tester.pumpAndSettle();
      expect(_built(tester), 1);
      expect(_rect(tester, 0), _rectNear(Offset.zero & _view));
      expect(gestures.last, _turn(to: 0));
    });

    testWidgets('nothing moves past either end', (tester) async {
      final gestures = await _pumpPages(tester, pageCount: 2);

      final before = await _down(tester, _centre);
      await _move(tester, before, const Offset(-0.6 * _w, 0));
      expect(_built(tester), 1);
      expect(_rect(tester, 0), _rectNear(Offset.zero & _view));
      await before.up(timeStamp: _tick());
      await tester.pumpAndSettle();
      expect(gestures, isEmpty);

      final next = await _down(tester, _centre);
      await _move(tester, next, const Offset(0.6 * _w, 0));
      await next.up(timeStamp: _tick());
      await tester.pumpAndSettle();
      expect(gestures, [_turn(to: 1)]);

      final after = await _down(tester, _centre);
      await _move(tester, after, const Offset(0.6 * _w, 0));
      expect(_built(tester), 1);
      expect(_rect(tester, 1), _rectNear(Offset.zero & _view));
      await after.up(timeStamp: _tick());
      await tester.pumpAndSettle();
      expect(gestures, hasLength(1));
    });

    testWidgets('a short slow drag held still cancels in motion-fast', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      final drag = await _down(tester, _centre);
      await _move(
        tester,
        drag,
        const Offset(0.4 * _w, 0),
        steps: 13,
        stepMs: 50,
      );
      expect(_rect(tester, 1).left, moreOrLessEquals(0.4 * _w - _w));
      await _holdAndLift(drag);
      expect(gestures.single, isA<PageTurnCancelled>());
      expect((gestures.single as PageTurnCancelled).zoom, 1);

      await tester.pump();
      await tester.pump(motionFast);
      await tester.pump();
      expect(_built(tester), 1);
      expect(_rect(tester, 0), _rectNear(Offset.zero & _view));
    });

    testWidgets('a fling against the turn cancels it, even past half', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      for (final travel in const [0.6 * _w, 0.3 * _w]) {
        final drag = await _down(tester, _centre);
        await _move(tester, drag, Offset(travel, 0), stepMs: 50);
        await _flick(tester, drag, const Offset(-30, 0));
        await tester.pumpAndSettle();
        expect(_built(tester), 1);
        expect(_rect(tester, 0), _rectNear(Offset.zero & _view));
      }
      expect(gestures, [isA<PageTurnCancelled>(), isA<PageTurnCancelled>()]);
    });

    testWidgets('a turn released by an upward flick is no fling', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      final drag = await _down(tester, _centre);
      await _move(tester, drag, const Offset(0.2 * _w, 0), stepMs: 50);
      await _flick(tester, drag, const Offset(10, -200));
      await tester.pumpAndSettle();
      expect(gestures, [isA<PageTurnCancelled>()]);
      expect(_rect(tester, 0), _rectNear(Offset.zero & _view));
    });

    testWidgets('an upward flick drifting sideways turns nothing', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      final flick = await _down(tester, _centre);
      await _flick(tester, flick, const Offset(6, -200));
      await tester.pumpAndSettle();
      expect(gestures, isEmpty);
      expect(_built(tester), 1);
    });

    testWidgets('a short fling turns', (tester) async {
      final gestures = await _pumpPages(tester);
      await tester.fling(
        find.byType(SyntheticPages),
        const Offset(60, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(gestures, [_turn(to: 1)]);
      expect(_built(tester), 1);
      expect(_rect(tester, 1), _rectNear(Offset.zero & _view));
    });
  });

  group('zoom and pan', () {
    testWidgets('a pinch zooms to 4 at most and back to 1', (tester) async {
      final gestures = await _pumpPages(tester);
      await _pinch(tester, _centre, 10, 60);
      expect(_rect(tester, 0).width, moreOrLessEquals(4 * _w));
      expect(_rect(tester, 0).height, moreOrLessEquals(4 * _h));
      expect(gestures.single, isA<PageZoom>());
      expect((gestures.single as PageZoom).zoom, 4);

      await _pinch(tester, _centre, 60, 5);
      expect(_rect(tester, 0), _rectNear(Offset.zero & _view));
      expect((gestures.last as PageZoom).zoom, 1);
    });

    for (final corner in const [
      Offset(20, 20),
      Offset(_w - 20, 20),
      Offset(20, _h - 20),
      Offset(_w - 20, _h - 20),
    ]) {
      testWidgets('a pinch about $corner keeps the page over the pager', (
        tester,
      ) async {
        await _pumpPages(tester);
        await _pinch(tester, _centre, 10, 60);
        await _pinch(tester, corner, 15, 8);
        final page = _rect(tester, 0);
        expect(page.width, lessThan(4 * _w));
        expect(page.width, greaterThan(_w));
        expect(page.left, lessThanOrEqualTo(1e-6));
        expect(page.top, lessThanOrEqualTo(1e-6));
        expect(page.right, greaterThanOrEqualTo(_w - 1e-6));
        expect(page.bottom, greaterThanOrEqualTo(_h - 1e-6));
      });
    }

    testWidgets('a pinch counts from its first move, about the fingers', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      final a = await _down(tester, const Offset(130, 320));
      await a.moveBy(const Offset(0, 40), timeStamp: _tick());
      await tester.pump();
      final b = await _down(tester, const Offset(230, 360));
      // The first move starts the pinch at focal (155, 360), span 75; the
      // second ends it at (180, 360), span 100: zoom 4/3, and the page point
      // (155, 360) is drawn under the fingers.
      await a.moveBy(const Offset(-50, 0), timeStamp: _tick());
      await tester.pump();
      await b.moveBy(const Offset(50, 0), timeStamp: _tick());
      await tester.pump();
      await a.up(timeStamp: _tick());
      await b.up(timeStamp: _tick());
      await tester.pump();
      expect((gestures.single as PageZoom).zoom, moreOrLessEquals(4 / 3));
      expect(
        _rect(tester, 0),
        _rectNear(
          const Rect.fromLTWH(
            180 - 155 * 4 / 3,
            360 - 360 * 4 / 3,
            _w * 4 / 3,
            _h * 4 / 3,
          ),
        ),
      );
    });

    testWidgets('zoomed, a drag pans to the edge before it turns', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      await _zoomTo2(tester);
      expect(gestures, [isA<PageZoom>().having((g) => g.zoom, 'zoom', 2)]);
      expect(
        _rect(tester, 0),
        _rectNear(const Rect.fromLTWH(-180, -360, 2 * _w, 2 * _h)),
      );

      final short = await _down(tester, _centre);
      await _move(tester, short, const Offset(180, 0));
      expect(_built(tester), 1);
      expect(_rect(tester, 0).left, moreOrLessEquals(0));
      await _move(tester, short, const Offset(60, 0), steps: 3, stepMs: 50);
      expect(_built(tester), 2);
      expect(_rect(tester, 1).left, moreOrLessEquals(60 - _w));
      expect(_rect(tester, 1).width, moreOrLessEquals(_w));
      await _holdAndLift(short);
      await tester.pumpAndSettle();
      expect(
        gestures.last,
        isA<PageTurnCancelled>().having((g) => g.zoom, 'zoom', 2),
      );
      expect(_built(tester), 1);
      expect(
        _rect(tester, 0),
        _rectNear(const Rect.fromLTWH(0, -360, 2 * _w, 2 * _h)),
      );

      final long = await _down(tester, _centre);
      await _move(tester, long, const Offset(200, 0));
      expect(_rect(tester, 1).left, moreOrLessEquals(200 - _w));
      await _holdAndLift(long);
      await tester.pumpAndSettle();
      expect(gestures.last, _turn(to: 1, zoom: 2));
      expect(_built(tester), 1);
      expect(_rect(tester, 1), _rectNear(Offset.zero & _view));
    });

    testWidgets('zoomed, a fling turns only from the edge it began at', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      await _zoomTo2(tester);

      final toEdge = await _down(tester, _centre);
      await _flick(tester, toEdge, const Offset(190, 0));
      await tester.pumpAndSettle();
      expect(
        gestures.last,
        isA<PageTurnCancelled>().having((g) => g.zoom, 'zoom', 2),
      );
      expect(_built(tester), 1);
      expect(_rect(tester, 0).left, moreOrLessEquals(0));

      final up = await _down(tester, _centre);
      await _flick(tester, up, const Offset(6, -200));
      await tester.pumpAndSettle();
      expect(gestures.whereType<PageTurn>(), isEmpty);
      expect(_built(tester), 1);
      expect(_rect(tester, 0).left, moreOrLessEquals(0));

      final fromEdge = await _down(tester, _centre);
      await _flick(tester, fromEdge, const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(gestures.last, _turn(to: 1, zoom: 2));
      expect(_rect(tester, 1), _rectNear(Offset.zero & _view));
    });

    testWidgets('after a pinch, the finger left drags without turning', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      final a = await _down(tester, _centre - const Offset(0, 30));
      final b = await _down(tester, _centre + const Offset(0, 30));
      for (var i = 0; i < 7; i++) {
        await a.moveBy(const Offset(0, -4), timeStamp: _tick());
        await b.moveBy(const Offset(0, 4), timeStamp: _tick());
        await tester.pump();
      }
      await b.up(timeStamp: _tick());
      await tester.pump();
      final zoom = (gestures.single as PageZoom).zoom;
      expect(zoom, greaterThan(1));
      await _move(tester, a, const Offset(0.6 * _w, 0));
      expect(_built(tester), 1);
      expect(_rect(tester, 0).left, moreOrLessEquals(0));
      await _holdAndLift(a);
      await tester.pumpAndSettle();
      expect(gestures, [isA<PageZoom>()]);
    });

    testWidgets('a pinch drifting 0.6 width turns nothing', (tester) async {
      final gestures = await _pumpPages(tester);
      await _pinch(tester, _centre, 30, 36, drift: const Offset(0.6 * _w, 0));
      await tester.pumpAndSettle();
      expect(_built(tester), 1);
      expect(gestures.whereType<PageTurn>(), isEmpty);
      expect(gestures.whereType<PageTurnCancelled>(), isEmpty);
      expect(gestures.single, isA<PageZoom>());
    });

    testWidgets('a second finger mid-turn does not zoom', (tester) async {
      final gestures = await _pumpPages(tester);
      final a = await _down(tester, const Offset(200, 300));
      await _move(tester, a, const Offset(100, 0));
      expect(_built(tester), 2);
      final b = await _down(tester, const Offset(150, 450));
      for (var i = 0; i < 6; i++) {
        await a.moveBy(const Offset(10, -10), timeStamp: _tick());
        await b.moveBy(const Offset(-10, 10), timeStamp: _tick());
        await tester.pump();
      }
      expect(_rect(tester, 0).width, moreOrLessEquals(_w));
      expect(_rect(tester, 1).width, moreOrLessEquals(_w));
      await a.up(timeStamp: _tick());
      await b.up(timeStamp: _tick());
      await tester.pumpAndSettle();
      expect(gestures.whereType<PageZoom>(), isEmpty);
      expect(_built(tester), 1);
    });
  });

  group('reduce motion', () {
    testWidgets('the turn is not drawn and commits as a cross-fade', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester, reduceMotion: true);
      final drag = await _down(tester, _centre);
      await _move(tester, drag, const Offset(0.6 * _w, 0));
      expect(_built(tester), 1);
      expect(_rect(tester, 0), _rectNear(Offset.zero & _view));
      await drag.up(timeStamp: _tick());
      expect(gestures, [_turn(to: 1, fade: true)]);

      await tester.pump();
      await tester.pump(motionSlow ~/ 2);
      expect(_built(tester), 2);
      double opacity(int page) => tester
          .widget<Opacity>(
            find.ancestor(of: _page(page), matching: find.byType(Opacity)),
          )
          .opacity;
      for (final page in [0, 1]) {
        expect(_rect(tester, page), _rectNear(Offset.zero & _view));
        expect(opacity(page), inExclusiveRange(0, 1));
      }
      expect(opacity(0) + opacity(1), moreOrLessEquals(1));

      await tester.pump(
        motionSlow - motionSlow ~/ 2 - const Duration(milliseconds: 1),
      );
      expect(_built(tester), 2);
      await tester.pumpAndSettle();
      expect(_built(tester), 1);
      expect(_page(1), findsOneWidget);
      expect(opacity(1), 1);
    });

    testWidgets('without it the turn slides', (tester) async {
      await _pumpPages(tester);
      final drag = await _down(tester, _centre);
      await _move(tester, drag, const Offset(0.6 * _w, 0));
      await drag.up(timeStamp: _tick());
      await tester.pump();
      await tester.pump(motionSlow ~/ 2);
      expect(_rect(tester, 1).left, inExclusiveRange(-_w, 0));
      expect(_rect(tester, 1).left, greaterThan(0.6 * _w - _w));
      await tester.pumpAndSettle();
    });
  });

  group('taps', () {
    final layout = syntheticPageLayout(_view);

    testWidgets('a tap reports the line under it, or the margin', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      final bar3 = layout.lines[2].center;
      await tester.tapAt(bar3);
      await tester.tapAt(const Offset(10, _h / 2));
      await tester.tapAt(layout.number.center);
      final taps = gestures.cast<PageTap>();
      expect(taps.map((t) => t.line), [3, null, null]);
      expect(taps.first.point, offsetMoreOrLessEquals(bar3));
      expect(taps.every((t) => t.page == 0), isTrue);
    });

    testWidgets('zoomed, the tap gets the line under the finger', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      await _zoomTo2(tester);
      final origin = _rect(tester, 0).topLeft;
      final bar9 = layout.lines[8].center;
      await tester.tapAt(origin + bar9 * 2);
      final tap = gestures.last as PageTap;
      expect(tap.line, 9);
      expect(tap.point, offsetMoreOrLessEquals(bar9));
    });

    testWidgets('the tap fires on the up, with no frame between', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      final finger = await _down(tester, _centre);
      expect(gestures, isEmpty);
      await finger.up(timeStamp: _tick());
      expect(gestures.single, isA<PageTap>());
    });

    testWidgets('no double-tap or long-press recogniser', (tester) async {
      await _pumpPages(tester);
      final detector = tester.widget<RawGestureDetector>(
        find.descendant(
          of: find.byType(SyntheticPages),
          matching: find.byType(RawGestureDetector),
        ),
      );
      expect(detector.gestures.keys.toSet(), {
        TapGestureRecognizer,
        ScaleGestureRecognizer,
      });
    });

    testWidgets('a 17 px drift still taps; 19 px does not', (tester) async {
      final gestures = await _pumpPages(tester);
      for (final drift in const [17.0, 19.0]) {
        final finger = await _down(tester, _centre);
        await finger.moveBy(Offset(drift, 0), timeStamp: _tick());
        await finger.up(timeStamp: _tick());
        await tester.pump();
      }
      expect(gestures, [isA<PageTap>()]);
    });

    testWidgets('a down mid-slide completes it and taps nothing', (
      tester,
    ) async {
      final gestures = await _pumpPages(tester);
      final drag = await _down(tester, _centre);
      await _move(tester, drag, const Offset(0.6 * _w, 0));
      await drag.up(timeStamp: _tick());
      await tester.pump();
      await tester.pump(motionSlow ~/ 3);
      expect(_built(tester), 2);

      await tester.tapAt(_centre);
      await tester.pump();
      expect(_built(tester), 1);
      expect(_rect(tester, 1), _rectNear(Offset.zero & _view));
      expect(gestures, [_turn(to: 1)]);
    });
  });

  group('identity', () {
    for (final theme in ReadingTheme.values) {
      testWidgets('colours from the ${theme.name} tokens', (tester) async {
        await _pumpPages(tester, theme: theme);
        final colors = buildAppTheme(theme).extension<AppColors>()!;
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: _page(0),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as SyntheticPagePainter;
        expect(painter.bar, colors.conceal);
        expect(painter.ground, colors.ground);
        expect(painter.rule, colors.lineStrong);
        final layout = syntheticPageLayout(_view);
        final drawn = paints
          ..rect(rect: Offset.zero & _view, color: colors.ground);
        for (final line in layout.lines) {
          drawn.rect(rect: line, color: colors.conceal);
        }
        for (final rule in layout.rules) {
          drawn.rect(rect: rule, color: colors.lineStrong);
        }
        expect(
          find.descendant(of: _page(0), matching: find.byType(CustomPaint)),
          drawn,
        );
        final number = tester.widget<Text>(
          find.descendant(of: _page(0), matching: find.byType(Text)),
        );
        expect(number.style!.color, colors.accent);
        // Mushaf.dc.html draws the page number at 15 px, weight 600, in the
        // interface face: the caption's face at the board's size.
        expect(number.style!.fontSize, 15);
        expect(number.style!.fontWeight, AppTextStyles.caption.fontWeight);
        expect(number.style!.fontFamily, AppTextStyles.caption.fontFamily);
        expect(number.textScaler, TextScaler.noScaling);
        for (final box in tester.widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(SyntheticPages),
            matching: find.byType(ColoredBox),
          ),
        )) {
          expect(box.color, colors.ground);
        }
      });
    }

    testWidgets('no Quran text; the only text is Arabic-Indic digits', (
      tester,
    ) async {
      await _pumpPages(tester);
      final drag = await _down(tester, _centre);
      await _move(tester, drag, const Offset(0.3 * _w, 0));
      expect(_built(tester), 2);
      expect(find.byType(QuranText), findsNothing);
      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(texts, hasLength(2));
      for (final text in texts) {
        expect(
          text.data!.codeUnits.every((u) => u >= 0x0660 && u <= 0x0669),
          isTrue,
          reason: text.data,
        );
      }
      await drag.up(timeStamp: _tick());
      await tester.pumpAndSettle();
    });

    test('the four S7 files are ASCII', () {
      for (final name in const [
        'synthetic_pages',
        'synthetic_pages_test',
        'gesture_log',
        'gesture_log_test',
      ]) {
        final bytes = File('spike/s7/$name.dart').readAsBytesSync();
        expect(bytes.every((b) => b < 0x80), isTrue, reason: name);
      }
    });
  });
}
