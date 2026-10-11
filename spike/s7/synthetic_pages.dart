import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/motion.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// What the pager reports to its owner (PRD 7.4, page mode).
sealed class PageGesture {
  const PageGesture(this.page);

  /// The page shown when the gesture happened.
  final int page;
}

/// A single tap. [point] is in the page's own, unzoomed coordinates; [line]
/// is the 1-based line whose band holds it, null on the margin.
final class PageTap extends PageGesture {
  const PageTap({required int page, required this.line, required this.point})
    : super(page);

  final int? line;
  final Offset point;
}

/// A turn committed from [page] to [to], at the [zoom] [page] had; [fade]
/// when it is drawn as a cross-fade ("reduce motion", AX-06).
final class PageTurn extends PageGesture {
  const PageTurn({
    required int page,
    required this.to,
    required this.zoom,
    required this.fade,
  }) : super(page);

  final int to;
  final double zoom;
  final bool fade;
}

/// A turn released short of committing.
final class PageTurnCancelled extends PageGesture {
  const PageTurnCancelled({required int page, required this.zoom})
    : super(page);

  final double zoom;
}

/// A pinch ended at [zoom].
final class PageZoom extends PageGesture {
  const PageZoom({required int page, required this.zoom}) : super(page);

  final double zoom;
}

/// RD-03: fifteen lines a page; the page number takes a sixteenth band.
const int _lineCount = 15;
const int _bandCount = _lineCount + 1;

/// A line of `.qk-quran-page` is 2.3em high; in it `.qk-conceal` paints a
/// 0.62em strip (`background-size: 100% 0.62em`) and underlines it in
/// `line-strong`, 2 px thick and 0.05em below
/// (design/design-system/components/bundle.css).
const double _bandEm = 2.3;
const double _barEm = 0.62;
const double _ruleGapEm = 0.05;
const double _ruleThickness = 2;

/// The page number's size at the foot of the drawn page
/// (design/identity-boards/Mushaf.dc.html: 15 px, weight 600, dark gold).
const double _pageNumberSize = 15;

/// RD-07: page mode zooms by pinch up to four times.
const double _minZoom = 1;
const double _maxZoom = 4;

/// The bars of a synthetic page of [page]'s size, top to bottom, the rule
/// under each, and the band of its number: the page inset by `space-5`, cut
/// into sixteen equal bands, a bar centred in each of the first fifteen. A
/// bar stands for a line's run of words.
({List<Rect> lines, List<Rect> rules, Rect number}) syntheticPageLayout(
  Size page,
) {
  const inset = AppSpacing.space5;
  final inner = Rect.fromLTRB(
    inset,
    inset,
    page.width - inset,
    page.height - inset,
  );
  final band = inner.height / _bandCount;
  final em = band / _bandEm;
  final bar = em * _barEm;
  final lines = [
    for (var i = 0; i < _lineCount; i++)
      Rect.fromLTWH(
        inner.left,
        inner.top + band * i + (band - bar) / 2,
        inner.width,
        bar,
      ),
  ];
  return (
    lines: lines,
    rules: [
      for (final line in lines)
        Rect.fromLTWH(
          line.left,
          line.bottom + em * _ruleGapEm,
          line.width,
          _ruleThickness,
        ),
    ],
    number: Rect.fromLTWH(
      inner.left,
      inner.top + band * _lineCount,
      inner.width,
      band,
    ),
  );
}

double clampPageZoom(double zoom) => zoom.clamp(_minZoom, _maxZoom);

/// [pan] kept so that a [page]-sized page drawn at [zoom] covers the pager.
Offset clampPagePan(Offset pan, double zoom, Size page) => Offset(
  pan.dx.clamp(page.width * (1 - zoom), 0.0),
  pan.dy.clamp(page.height * (1 - zoom), 0.0),
);

/// Splits one finger's horizontal travel [x] (pan plus turn) into the pan
/// of a page at [zoom] and the turn beyond it. A positive turn brings the
/// next page in from the left, a negative one the previous from the right.
({double pan, double turn}) splitDrag(
  double x, {
  required double zoom,
  required double width,
  required bool hasPrevious,
  required bool hasNext,
}) {
  final pan = x.clamp(width * (1 - zoom), 0.0);
  final turn = (x - pan).clamp(
    hasPrevious ? -width : 0.0,
    hasNext ? width : 0.0,
  );
  return (pan: pan, turn: turn);
}

/// Synthetic mushaf pages for S7: horizontal drag turns, pinch zooms with
/// pan, a tap reports the line or the margin (PRD 7.4, RD-07, RD-11, AX-06).
/// Built on one [GestureDetector] rather than PageView and
/// InteractiveViewer, which expose neither the pan's overflow into a turn nor
/// a stacked cross-fade.
class SyntheticPages extends StatefulWidget {
  const SyntheticPages({required this.pageCount, this.onGesture, super.key})
    : assert(pageCount > 0, 'at least one page');

  final int pageCount;
  final ValueChanged<PageGesture>? onGesture;

  @override
  State<SyntheticPages> createState() => _SyntheticPagesState();
}

sealed class _Motion {}

/// The turn running from [from] to [to]; to the page [target] when it
/// commits.
final class _Slide extends _Motion {
  _Slide(this.from, this.to, this.target);

  final double from;
  final double to;
  final int? target;
}

/// The page left, fading out where it was.
final class _Fade extends _Motion {
  _Fade(this.page, this.pan, this.zoom);

  final int page;
  final Offset pan;
  final double zoom;
}

class _SyntheticPagesState extends State<SyntheticPages>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this)
    ..addStatusListener(_onMotionStatus);
  _Motion? _running;

  int _page = 0;
  double _zoom = 1;

  /// A page point p is drawn at `_pan + p * _zoom`.
  Offset _pan = Offset.zero;
  double _turn = 0;
  Size _size = Size.zero;
  bool _reduceMotion = false;

  // The touch sequence: from the first finger down to the last up.
  int _pointers = 0;
  Offset _downAt = Offset.zero;
  bool _tapsNothing = false;
  bool _pinched = false;
  bool _turned = false;
  bool _open = false;
  double _x = 0;

  /// Whether the sequence's first drag ran more across than down; only such
  /// a drag turns (RD-11).
  bool? _horizontal;

  /// Whether the drag began with the page at its left or right edge; only
  /// then may a fling commit a turn that way.
  bool _fromLeftEdge = false;
  bool _fromRightEdge = false;

  bool _pinching = false;

  /// The zoom the pinch counts its scale from and the page point kept under
  /// its focal point. Taken at the pinch's first update: the recogniser
  /// starts it a move after the second finger lands, when the focal point has
  /// shifted but the scale still counts from the landing.
  ({double zoom, Offset point})? _pinch;

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _emit(PageGesture gesture) => widget.onGesture?.call(gesture);

  void _onPointerDown(PointerDownEvent event) {
    if (_pointers++ == 0) {
      _downAt = event.localPosition;
      _horizontal = null;
      _tapsNothing = false;
      _pinched = false;
      _turned = false;
    }
    if (_running != null) {
      _motion.stop();
      _finishMotion();
      _tapsNothing = true;
    }
  }

  void _onPointerUp(PointerEvent event) {
    if (_pointers == 0) return;
    if (--_pointers > 0) return;
    // The scale recogniser sends no end when the last finger lifts unmoved
    // after another lifted. When an end does come, it is dispatched after
    // this listener but before the microtask, which then finds nothing open.
    scheduleMicrotask(() {
      if (mounted && _open && _pointers == 0) _release(Offset.zero);
    });
  }

  void _onTapUp(TapUpDetails details) {
    if (_tapsNothing) return;
    final point = (details.localPosition - _pan) / _zoom;
    _emit(PageTap(page: _page, line: _lineAt(point), point: point));
  }

  int? _lineAt(Offset point) {
    final layout = syntheticPageLayout(_size);
    final band = layout.number.height;
    for (final (i, bar) in layout.lines.indexed) {
      final rect = Rect.fromCenter(
        center: bar.center,
        width: bar.width,
        height: band,
      );
      if (rect.contains(point)) return i + 1;
    }
    return null;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _open = true;
    _pinch = null;
    _pinching = details.pointerCount >= 2 && !_turned;
    if (_pinching) {
      _pinched = true;
    } else {
      _x = _pan.dx + _turn;
      _fromLeftEdge = _pan.dx >= 0;
      _fromRightEdge = _pan.dx <= _size.width * (1 - _zoom);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_pinching) {
      final pinch = _pinch ??= (
        zoom: _zoom / details.scale,
        point: (details.localFocalPoint - _pan) / _zoom,
      );
      final zoom = clampPageZoom(pinch.zoom * details.scale);
      setState(() {
        _zoom = zoom;
        _pan = clampPagePan(
          details.localFocalPoint - pinch.point * zoom,
          zoom,
          _size,
        );
      });
      return;
    }
    final travel = details.localFocalPoint - _downAt;
    final turns =
        !_pinched && (_horizontal ??= travel.dx.abs() > travel.dy.abs());
    final delta = details.focalPointDelta;
    final split = splitDrag(
      _x + delta.dx,
      zoom: _zoom,
      width: _size.width,
      hasPrevious: turns && _page > 0,
      hasNext: turns && _page < widget.pageCount - 1,
    );
    setState(() {
      _x = split.pan + split.turn;
      _turn = split.turn;
      _pan = clampPagePan(Offset(split.pan, _pan.dy + delta.dy), _zoom, _size);
      if (_turn != 0) _turned = true;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_pinching && details.pointerCount < 2) {
      _pinching = false;
      _pinch = null;
      _emit(PageZoom(page: _page, zoom: _zoom));
    }
    if (details.pointerCount == 0) {
      _release(details.velocity.pixelsPerSecond);
    }
  }

  void _release(Offset velocity) {
    _open = false;
    _pinching = false;
    _pinch = null;
    final turn = _turn;
    if (turn == 0) return;
    final width = _size.width;
    if (!_commits(turn, velocity)) {
      _emit(PageTurnCancelled(page: _page, zoom: _zoom));
      if (_reduceMotion) {
        setState(() => _turn = 0);
      } else {
        _start(_Slide(turn, 0, null), motionFast);
      }
      return;
    }
    final to = turn > 0 ? _page + 1 : _page - 1;
    _emit(PageTurn(page: _page, to: to, zoom: _zoom, fade: _reduceMotion));
    if (!_reduceMotion) {
      _start(_Slide(turn, turn.sign * width, to), motionSlow);
      return;
    }
    final leaving = _Fade(_page, _pan, _zoom);
    _showPage(to);
    _start(leaving, motionSlow);
  }

  /// A horizontal fling decides by its direction, but commits only from the
  /// edge the drag began at: a zoomed page flung to its edge stays. Any other
  /// release commits past half the width.
  bool _commits(double turn, Offset velocity) {
    final vx = velocity.dx;
    final fling = vx.abs() > kMinFlingVelocity && vx.abs() > velocity.dy.abs();
    if (fling && vx.sign != turn.sign) return false;
    if (fling && (turn > 0 ? _fromLeftEdge : _fromRightEdge)) return true;
    return turn.abs() > _size.width / 2;
  }

  void _start(_Motion motion, Duration duration) {
    setState(() => _running = motion);
    _motion
      ..duration = duration
      ..forward(from: 0);
  }

  void _onMotionStatus(AnimationStatus status) {
    if (status.isCompleted && _running != null) _finishMotion();
  }

  void _finishMotion() {
    final running = _running;
    setState(() {
      _running = null;
      if (running case _Slide(:final target)) {
        if (target != null) {
          _showPage(target);
        } else {
          _turn = 0;
        }
      }
    });
  }

  void _showPage(int page) {
    _page = page;
    _zoom = 1;
    _pan = Offset.zero;
    _turn = 0;
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final ground = context.colors.ground;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size != _size) {
          _size = size;
          _pan = clampPagePan(_pan, _zoom, size);
        }
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerUp,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _onTapUp,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: ClipRect(
              // Under a cross-fade the two grounds sum to the page's ground.
              child: ColoredBox(
                color: ground,
                child: AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) => Stack(children: _pages(size)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _pages(Size size) {
    final running = _running;
    final t = motionCurve.transform(_motion.value);
    if (running is _Fade) {
      return [
        _placed(running.page, running.pan, running.zoom, 1 - t),
        _placed(_page, Offset.zero, 1, t),
      ];
    }
    final turn = switch (running) {
      _Slide(:final from, :final to) => lerpDouble(from, to, t)!,
      _ => _reduceMotion ? 0.0 : _turn,
    };
    return [
      if (turn > 0) _placed(_page + 1, Offset(turn - size.width, 0), 1, 1),
      if (turn < 0) _placed(_page - 1, Offset(turn + size.width, 0), 1, 1),
      _placed(_page, _pan + Offset(turn, 0), _zoom, 1),
    ];
  }

  Widget _placed(int page, Offset offset, double zoom, double opacity) =>
      Positioned.fill(
        key: ValueKey(page),
        child: Opacity(
          opacity: opacity,
          child: Transform(
            transform: Matrix4.diagonal3Values(zoom, zoom, 1)
              ..setTranslationRaw(offset.dx, offset.dy, 0),
            child: SyntheticPage(page),
          ),
        ),
      );
}

/// One synthetic page: fifteen `conceal` bars underlined in `line-strong`
/// on `ground`, and its number in `accent`. The number keeps its size whatever the text scale: a page grows
/// by pinch only (design/design-system/README.md, type).
class SyntheticPage extends StatelessWidget {
  const SyntheticPage(this.index, {super.key});

  /// 0-based; shown 1-based.
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = syntheticPageLayout(constraints.biggest);
        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SyntheticPagePainter(
                    ground: colors.ground,
                    bar: colors.conceal,
                    rule: colors.lineStrong,
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: layout.number,
              child: Center(
                child: Text(
                  arabicDigits(index + 1),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: _pageNumberSize,
                    color: colors.accent,
                  ),
                  textScaler: TextScaler.noScaling,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Paints [syntheticPageLayout]'s bars, square, in [bar] with their rules in
/// [rule], on [ground].
class SyntheticPagePainter extends CustomPainter {
  const SyntheticPagePainter({
    required this.ground,
    required this.bar,
    required this.rule,
  });

  final Color ground;
  final Color bar;
  final Color rule;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final layout = syntheticPageLayout(size);
    final barPaint = Paint()..color = bar;
    for (final line in layout.lines) {
      canvas.drawRect(line, barPaint);
    }
    final rulePaint = Paint()..color = rule;
    for (final line in layout.rules) {
      canvas.drawRect(line, rulePaint);
    }
  }

  @override
  bool shouldRepaint(SyntheticPagePainter oldDelegate) =>
      oldDelegate.ground != ground ||
      oldDelegate.bar != bar ||
      oldDelegate.rule != rule;
}
