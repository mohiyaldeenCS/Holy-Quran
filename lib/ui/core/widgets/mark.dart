import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';

/// The colours of the mark (`MARK_VARIANTS` in index.jsx).
enum MarkVariant {
  /// On the theme's ground; follows the theme.
  paper,

  /// On emerald, as on the splash and share cards. Fixed brand colours.
  emerald,

  /// On the deepest emerald. Fixed brand colours.
  dark,

  /// In the current text colour, unfilled, for print and embroidery.
  mono,
}

/// The app's mark: the quarter star holding an open book, with the dot above
/// it from 32 px up. The stroke thickens as the mark shrinks.
///
/// Its accessible name is the app's name; [decorative] removes it when text
/// beside the mark already says the name.
final class Mark extends StatelessWidget {
  const Mark({
    this.size = _defaultSize,
    this.variant = MarkVariant.paper,
    this.decorative = false,
    super.key,
  });

  final double size;
  final MarkVariant variant;
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(
        colours: _coloursOf(context),
        stroke: markStroke(size),
        dotRadius: markDotRadius(size),
      ),
    );
    if (decorative) return ExcludeSemantics(child: mark);
    return Semantics(
      container: true,
      image: true,
      label: AppLocalizations.of(context).appTitle,
      child: ExcludeSemantics(child: mark),
    );
  }

  _MarkColours _coloursOf(BuildContext context) => switch (variant) {
    MarkVariant.paper => (
      star: context.colors.ornament,
      book: context.colors.brandInk,
      fill: _paperFill,
    ),
    MarkVariant.emerald => (
      star: Ramps.gold400,
      book: Ramps.paper100,
      fill: _emeraldFill,
    ),
    MarkVariant.dark => (
      star: Ramps.gold400,
      book: AppColors.night.ink,
      fill: _darkFill,
    ),
    MarkVariant.mono => (
      star: _current(context),
      book: _current(context),
      fill: null,
    ),
  };
}

// `currentColor` in MARK_VARIANTS.mono, taken as `Icon` takes it.
Color _current(BuildContext context) =>
    IconTheme.of(context).color ?? context.colors.ink;

typedef _MarkColours = ({Color star, Color book, double? fill});

/// The star's stroke for a mark of [size], in units of the 120 viewBox.
@visibleForTesting
double markStroke(double size) => _strokeSteps
    .firstWhere((step) => size >= step.from, orElse: () => _smallestStep)
    .stroke;

/// The radius of the dot above the book, or null when [size] is too small to
/// carry it.
@visibleForTesting
double? markDotRadius(double size) => size < _dotMinSize
    ? null
    : size >= _smallDotFromSize
    ? _smallDotRadius
    : _largeDotRadius;

final class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.colours,
    required this.stroke,
    required this.dotRadius,
  });

  final _MarkColours colours;
  final double stroke;
  final double? dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = colours.fill;
    StarOutlinePainter(
      color: colours.star,
      stroke: stroke,
      fill: fill == null ? null : colours.star.withValues(alpha: fill),
    ).paint(canvas, size);

    const viewBox = StarOutlinePainter.viewBox;
    canvas
      ..save()
      ..scale(size.width / viewBox, size.height / viewBox)
      ..drawPath(buildMarkBookPath(), Paint()..color = colours.book);
    if (dotRadius case final radius?) {
      canvas.drawCircle(_dotCentre, radius, Paint()..color = colours.star);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      colours != oldDelegate.colours ||
      stroke != oldDelegate.stroke ||
      dotRadius != oldDelegate.dotRadius;
}

// Mark in index.jsx: `size = 48`.
const double _defaultSize = 48;

// `markStroke(size)` in index.jsx, in units of the 120 viewBox: the first
// step whose `from` the size reaches, else the smallest-size stroke.
const _strokeSteps = [
  (from: 96.0, stroke: 2.2),
  (from: 64.0, stroke: 3.0),
  (from: 48.0, stroke: 3.6),
  (from: 32.0, stroke: 5.0),
];
const _smallestStep = (from: 0.0, stroke: 6.5);

// MARK_VARIANTS in index.jsx: the star's `fill` opacity per variant; mono has
// none (`fill: 0`, drawn unfilled).
const double _paperFill = 0.14;
const double _emeraldFill = 0.14;
const double _darkFill = 0.12;

// Mark in index.jsx: `size >= 32 ? <circle cx="60" cy="39.5"
// r={size >= 64 ? 2.6 : 3.2} /> : null`.
const double _dotMinSize = 32;
const double _smallDotFromSize = 64;
const double _smallDotRadius = 2.6;
const double _largeDotRadius = 3.2;
const Offset _dotCentre = Offset(60, 39.5);
