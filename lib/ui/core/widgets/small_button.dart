import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';

// .qk-btn-small: height 44px; border-radius 14px.
const double _buttonHeight = 44;
const double _buttonRadius = 14;
// .qk-btn-small-outline: box-shadow inset 0 0 0 1.5px var(--line).
const double _outlineWidth = 1.5;

// .qk-btn-small: font-size 15px; font-weight 600, in the body's IBM Plex Sans
// Arabic with its `normal` line height.
const TextStyle _labelStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 15,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// `.qk-btn-small`, and its outline variant: 44 high in a target-min hit
/// area, radius 14, padded 16 on each side. `ResourceRow` draws its download
/// and delete with it, and the integrity alert its action.
class SmallButton extends StatelessWidget {
  const SmallButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  static final BorderRadius _radius = BorderRadius.circular(_buttonRadius);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A null background is the reference's `transparent`.
    final (Color? background, Color foreground) = outlined
        ? (null, colors.ink)
        : (colors.primary, colors.onPrimary);
    return Semantics(
      container: true,
      label: label,
      // Pressable covers the drawn face; this detector makes the rest of the
      // target-min height press it too, as in IconButton.
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
              // A DecoratedBox, as the inset outline takes no layout space.
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: _radius,
                    border: outlined
                        ? Border.all(color: colors.line, width: _outlineWidth)
                        : null,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: _buttonHeight,
                      minWidth: AppSizes.targetMin,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space4,
                      ),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: _labelStyle.copyWith(color: foreground),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
