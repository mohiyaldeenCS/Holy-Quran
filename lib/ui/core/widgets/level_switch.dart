import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';

// .qk-seg: border-radius 18px.
const BorderRadius _groupRadius = BorderRadius.all(Radius.circular(18));
// .qk-seg-item: border-radius 14px.
const BorderRadius _itemRadius = BorderRadius.all(Radius.circular(14));
// .qk-seg-item: font-size 16px.
const double _itemFontSize = 16;

/// The identity's one segmented control (`LevelSwitch`, `.qk-seg`): the
/// interface level, and every other choice of one among a few. Items share
/// the width and are at least target-min high.
class LevelSwitch extends StatelessWidget {
  const LevelSwitch({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceSunk,
          borderRadius: _groupRadius,
        ),
        child: Padding(
          // .qk-seg: padding 4px; gap 4px.
          padding: const EdgeInsets.all(AppSpacing.space1),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.space1,
              children: [
                for (final (index, option) in options.indexed)
                  Expanded(
                    child: _Item(
                      label: option,
                      selected: index == selectedIndex,
                      onTap: () => onChanged(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final face = DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? colors.primary : null,
        borderRadius: _itemRadius,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: _itemFontSize,
              // .qk-seg-item: font-weight 500; .is-on: 600.
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? colors.onPrimary : colors.ink,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FocusRing(
          radius: _itemRadius,
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) => onTap(),
              ),
            },
            child: ExcludeSemantics(child: face),
          ),
        ),
      ),
    );
  }
}
