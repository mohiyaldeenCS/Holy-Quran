import 'dart:math' as math;

import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

// .qk-tabbar: padding 8px 8px 20px; the 20px bottom grows to the safe area.
const double _barBottomPadding = 20;
// .qk-tab: padding 6px 0.
const double _tabVerticalPadding = 6;
// .qk-tab: gap 2px.
const double _tabGap = 2;
// .qk-tab-pill: width 60px.
const double _pillWidth = 60;
// .qk-tab-pill: height 32px; border-radius 16px is half of it.
const double _pillHeight = 32;
const BorderRadius _pillRadius = BorderRadius.all(
  Radius.circular(_pillHeight / 2),
);

/// One tab of [TabBar]: its icon and its label.
@immutable
final class TabBarItem {
  const TabBarItem(this.icon, this.label);

  final IconName icon;
  final String label;
}

/// The identity's bottom navigation (`TabBar`, `.qk-tabbar`): equal tabs on
/// `surface` under a `line` hairline, the first on the right. The current tab
/// has a `primary-soft` pill behind its icon and a semibold label. The bottom
/// padding is the reference's 20 or the safe area, whichever is larger.
class TabBar extends StatelessWidget {
  const TabBar({
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.semanticLabel,
    super.key,
  });

  final List<TabBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottom = math.max(
      _barBottomPadding,
      MediaQuery.viewPaddingOf(context).bottom,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      // Container adds the 1px border to the padding, as CSS does.
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.line)),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space2,
          AppSpacing.space2,
          AppSpacing.space2,
          bottom,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, item) in items.indexed)
                Expanded(
                  child: _Tab(
                    item: item,
                    selected: index == currentIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final TabBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // .qk-tab: color ink-muted; .is-on: on-primary-soft, for icon and label.
    final foreground = selected ? colors.onPrimarySoft : colors.inkMuted;
    final face = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _tabVerticalPadding),
        child: Column(
          spacing: _tabGap,
          children: [
            Container(
              width: _pillWidth,
              height: _pillHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? colors.primarySoft : null,
                borderRadius: _pillRadius,
              ),
              child: Icon(item.icon, color: foreground),
            ),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: AppTextStyles.tabLabel.copyWith(
                // .qk-tab-label: font-weight 500; .is-on: 600.
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FocusRing(
          radius: BorderRadius.zero,
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
