import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/ui/core/metrics/player_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';

/// A chip of the panel: [active] is the board's paper chip, the others its
/// tinted chips. Drawn 36 high in a target-min hit area; it grows with the
/// text.
class PlayerPanelChip extends StatelessWidget {
  const PlayerPanelChip({
    required this.label,
    required this.onPressed,
    this.active = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = active
        ? (colors.onPlayer, colors.player)
        : (
            colors.onPlayer.withValues(alpha: PlayerMetrics.tintOpacity),
            colors.onPlayer,
          );
    return Semantics(
      container: true,
      label: label,
      // Pressable covers the drawn chip; this detector makes the bands above
      // and below it, up to target-min, press it too, as in IconButton.
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
              focusRadius: PlayerMetrics.chipRadius,
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: PlayerMetrics.chipRadius,
                  ),
                  child: Padding(
                    padding: PlayerMetrics.chipPadding,
                    // A row in a minimum height centres the label and keeps
                    // the chip as wide as its text.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: PlayerMetrics.chipHeight,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: PlayerMetrics.chipText.copyWith(
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
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
