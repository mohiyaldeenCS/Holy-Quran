import 'dart:math' as math;

import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';

// .qk-tag: height 40px; border-radius var(--radius-full).
const double _height = 40;
const BorderRadius _radius = BorderRadius.all(
  Radius.circular(AppRadius.radiusFull),
);
// .qk-tag-dot: width and height 10px.
const double _dotSize = 10;
// .qk-tag-dot-circle, .qk-tag-dot-ring: border-radius 5px.
const BorderRadius _roundDotRadius = BorderRadius.all(Radius.circular(5));
// .qk-tag-dot-square: border-radius 2px.
const BorderRadius _squareDotRadius = BorderRadius.all(Radius.circular(2));
// .qk-tag-dot-ring: border 2px solid var(--tag-color).
const double _ringWidth = 2;
// ModeChips in index.jsx, `.qk-chip.is-on`: <Icon name="check" size={16} />.
const double _checkSize = 16;

// .qk-tag: font-size 15px; font-weight 500; .is-on: font-weight 600. No line
// height is set, so it is the font's own (CSS `normal`); the style does not
// inherit, so the ambient body line height cannot reach it.
const TextStyle _labelStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 15,
  fontWeight: FontWeight.w500,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The four shapes a category can take (`.qk-tag-dot-*`).
enum TagShape { circle, diamond, ring, square }

/// A category tag (`Tag`, `.qk-tag`), pressed to select it: a [shape] in
/// [color] and the category's [label], so the category is never told by
/// colour alone. Selected, it fills with `primary-soft` and carries the check
/// mark of `ModeChips` before the shape (D-089, 6).
///
/// [color] is the caller's: the category colours are not settled (O-14).
class Tag extends StatelessWidget {
  const Tag({
    required this.label,
    required this.shape,
    required this.color,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final TagShape shape;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.onPrimarySoft : colors.ink;
    // Container adds the 1px border to the padding, as CSS does. .is-on keeps
    // the border's width and makes it transparent: an undrawn side.
    final face = Container(
      constraints: const BoxConstraints(minHeight: _height),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
      decoration: BoxDecoration(
        color: selected ? colors.primarySoft : colors.surface,
        border: Border.all(
          color: colors.line,
          style: selected ? BorderStyle.none : BorderStyle.solid,
        ),
        borderRadius: _radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.space2,
        children: [
          if (selected)
            Icon(IconName.check, size: _checkSize, color: foreground),
          _Dot(shape: shape, color: color),
          Flexible(
            child: Text(
              label,
              style: _labelStyle.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      // Pressable states the button role. The reference's aria-pressed is
      // announced as selected, as chips are, not toggled, which reads as a
      // switch.
      selected: selected,
      label: label,
      // Pressable covers the drawn face, where the focus ring goes; this
      // detector makes the rest of the target-min height press it too.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Pressable(
              onPressed: onPressed,
              focusRadius: _radius,
              child: ExcludeSemantics(child: face),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.qk-tag-dot`: the category's shape, 10 by 10.
class _Dot extends StatelessWidget {
  const _Dot({required this.shape, required this.color});

  final TagShape shape;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dot = SizedBox.square(
      dimension: _dotSize,
      child: DecoratedBox(
        decoration: switch (shape) {
          TagShape.circle => BoxDecoration(
            color: color,
            borderRadius: _roundDotRadius,
          ),
          TagShape.square => BoxDecoration(
            color: color,
            borderRadius: _squareDotRadius,
          ),
          TagShape.diamond => BoxDecoration(color: color),
          // box-sizing: border-box, so the ring is drawn inside the 10.
          TagShape.ring => BoxDecoration(
            border: Border.all(color: color, width: _ringWidth),
            borderRadius: _roundDotRadius,
          ),
        },
      ),
    );
    // .qk-tag-dot-diamond: transform rotate(45deg), which leaves the layout
    // box as it is.
    return shape == TagShape.diamond
        ? Transform.rotate(angle: math.pi / 4, child: dot)
        : dot;
  }
}
