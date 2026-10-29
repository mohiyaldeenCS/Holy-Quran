import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';

/// The reader's position bar made a button (D-140, 11): a tap anywhere on it
/// runs [onPressed], in a hit area of at least `target-min`, with the focus
/// ring in keyboard mode. The bar keeps its own text in semantics, so a
/// screen reader hears the surah, the juz and the hizb with [label], the name
/// of what the button does.
final class PositionBarButton extends StatelessWidget {
  const PositionBarButton({
    required this.label,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;

  static final BorderRadius _radius = BorderRadius.circular(AppRadius.radiusSm);

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
      child: Pressable(
        onPressed: onPressed,
        focusRadius: _radius,
        child: Align(child: child),
      ),
    ),
  );
}
