import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';

// Button (index.jsx): <Icon size={22} /> before the label.
const double _iconSize = 22;
// .qk-btn-outline: box-shadow inset 0 0 0 1.5px var(--primary).
const double _outlineWidth = 1.5;

enum ButtonVariant { primary, outline, tonal, text }

/// The identity's button (`Button`, `.qk-btn`): at least 52 high, radius 16,
/// 17 px semibold, an optional icon before the label. Disabled when
/// [onPressed] is null. It has no pressed look, as the reference defines none.
class Button extends StatelessWidget {
  const Button({
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconName? icon;

  static final BorderRadius _radius = BorderRadius.circular(
    AppRadius.radiusButton,
  );

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (background, foreground, outline) = _colours(context.colors, enabled);
    final icon = this.icon;
    final face = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: _radius,
        border: outline == null
            ? null
            : Border.all(color: outline, width: _outlineWidth),
      ),
      child: ConstrainedBox(
        // The minimum width keeps a short label's hit area at target-min.
        constraints: const BoxConstraints(
          minHeight: AppSizes.buttonHeight,
          minWidth: AppSizes.targetMin,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: variant == ButtonVariant.text
                ? AppSpacing.space4
                : AppSpacing.space5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: AppSpacing.space2,
            children: [
              if (icon != null) Icon(icon, size: _iconSize, color: foreground),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyStrong.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      // Pressable states the button role and the disabled state; the enabled
      // state is announced here. A flag set twice would split the node.
      enabled: enabled ? true : null,
      label: label,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: _radius,
        child: ExcludeSemantics(child: face),
      ),
    );
  }

  // A null background is the reference's `transparent`.
  (Color? background, Color foreground, Color? outline) _colours(
    AppColors colors,
    bool enabled,
  ) {
    // .qk-btn:disabled overrides every variant's background, colour and ring.
    if (!enabled) return (colors.surfaceSunk, colors.inkDisabled, null);
    return switch (variant) {
      ButtonVariant.primary => (colors.primary, colors.onPrimary, null),
      ButtonVariant.outline => (null, colors.primary, colors.primary),
      ButtonVariant.tonal => (Ramps.gold100, Ramps.goldTextStrong, null),
      ButtonVariant.text => (null, colors.primary, null),
    };
  }
}
