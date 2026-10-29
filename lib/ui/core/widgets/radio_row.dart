import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';

/// One row of a single-choice list, as the copy forms of the Share board draw
/// it: a radio, then [child]. A row is a radio, not a button, as `ModeChips`'
/// chips are; a screen reader hears [label], or, without one, the text of
/// [child]. The row stands at least 48 high.
class RadioRow extends StatelessWidget {
  const RadioRow({
    required this.child,
    required this.selected,
    required this.onTap,
    this.label,
    super.key,
  });

  /// The text style of a row's label: Share.dc.html, each form, `font-size:
  /// 16px`, no line height set.
  static const TextStyle labelStyle = TextStyle(
    inherit: false,
    fontFamily: AppFonts.sans,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  final Widget child;
  final bool selected;
  final VoidCallback onTap;

  /// The spoken name of the row; null to read [child]'s own text.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ring = selected ? colors.primary : colors.lineStrong;
    final face = ConstrainedBox(
      // Share.dc.html, each form: `min-height:48px` (target-min).
      constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
      child: Row(
        // Share.dc.html, each form: `gap:12px` (space-3).
        spacing: AppSpacing.space3,
        children: [
          Container(
            width: _radioSize,
            height: _radioSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: _radioBorder),
            ),
            child: selected
                ? Container(
                    width: _dotSize,
                    height: _dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary,
                    ),
                  )
                : null,
          ),
          Expanded(child: child),
        ],
      ),
    );
    final label = this.label;
    return Semantics(
      container: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FocusRing(
          radius: _rowFocusRadius,
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) => onTap(),
              ),
            },
            child: label == null ? face : ExcludeSemantics(child: face),
          ),
        ),
      ),
    );
  }
}

// Share.dc.html, the radio: `width:22px;height:22px;border-radius:11px;
// border:2px solid`, #0E5A52 (primary) when selected with a
// `width:10px;height:10px` #0E5A52 dot. The unselected ring is #8C9794, which
// no token holds; line-strong is the token of a control's outline.
const double _radioSize = 22;
const double _radioBorder = 2;
const double _dotSize = 10;

// The board's rows have no corners, so neither has their focus ring.
const BorderRadius _rowFocusRadius = BorderRadius.zero;
