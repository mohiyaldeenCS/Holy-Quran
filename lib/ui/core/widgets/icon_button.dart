import 'dart:math' as math;

import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';

enum IconButtonTone { plain, tint, solid }

/// The identity's round icon-only button (`IconButton`, `.qk-iconbtn`).
/// [label] is mandatory: it is the name a screen reader reads. A button drawn
/// smaller than target-min still takes a target-min square for touch.
class IconButton extends StatelessWidget {
  const IconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tone = IconButtonTone.plain,
    this.size = AppSizes.targetMin,
    this.iconSize = AppSizes.iconSize,
    super.key,
  });

  final IconName icon;
  final String label;
  final VoidCallback onPressed;
  final IconButtonTone tone;
  final double size;
  final double iconSize;

  static final BorderRadius _radius = BorderRadius.circular(
    AppRadius.radiusFull,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A null background is the reference's `transparent`.
    final (Color? background, Color foreground) = switch (tone) {
      IconButtonTone.plain => (null, colors.primary),
      IconButtonTone.tint => (colors.surfaceSunk, colors.primary),
      IconButtonTone.solid => (colors.primary, colors.onPrimary),
    };
    final target = math.max(size, AppSizes.targetMin);
    return Semantics(
      container: true,
      label: label,
      // Pressable covers the drawn face, where the focus ring goes; this
      // detector makes the rest of the target-min square press it too. Its
      // tap action would repeat Pressable's and split the semantics node.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: target,
          child: Center(
            child: Pressable(
              onPressed: onPressed,
              focusRadius: _radius,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: _radius,
                ),
                child: Icon(icon, size: iconSize, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
