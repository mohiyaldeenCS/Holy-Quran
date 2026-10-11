import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';

// .qk-summary-sort: height 40px; padding 0 12px (space-3); border-radius
// 14px; gap 6px.
const double _sortHeight = 40;
const BorderRadius _sortRadius = BorderRadius.all(Radius.circular(14));
const double _sortGap = 6;
// SearchSummary in index.jsx: <Icon name="sort" size={18} />.
const double _sortIconSize = 18;

// No line height is set in `.qk-summary*`, so each is the font's own (CSS
// `normal`); the styles do not inherit, so the ambient body line height
// cannot reach them.
// .qk-summary-title: font-size 16px; font-weight 700.
const TextStyle _titleStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-summary-count: font-size 13px.
const TextStyle _countStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-summary-sort: font-size 14px, the button's 400.
const TextStyle _sortStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// What was searched and how many results (`SearchSummary`, `.qk-summary`):
/// the [title] over the [count] line, and at the row's end the sort control
/// showing the current [sortLabel].
///
/// The sort control's hit area is 48 high (`.qk-summary-sort::after`), so
/// the row is at least 48 high.
class SearchSummary extends StatelessWidget {
  const SearchSummary({
    required this.title,
    required this.count,
    required this.sortLabel,
    required this.onSort,
    super.key,
  });

  final String title;
  final String count;
  final String sortLabel;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      spacing: AppSpacing.space3,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _titleStyle.copyWith(color: colors.ink)),
              Text(count, style: _countStyle.copyWith(color: colors.inkMuted)),
            ],
          ),
        ),
        _Sort(label: sortLabel, onPressed: onSort),
      ],
    );
  }
}

class _Sort extends StatelessWidget {
  const _Sort({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Container adds the 1px border to the padding, as the button's
    // border-box does.
    final face = Container(
      constraints: const BoxConstraints(minHeight: _sortHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space3),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: _sortRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: _sortGap,
        children: [
          Icon(IconName.sort, size: _sortIconSize, color: colors.inkMuted),
          Text(label, style: _sortStyle.copyWith(color: colors.ink)),
        ],
      ),
    );
    return Semantics(
      container: true,
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
            child: Pressable(
              onPressed: onPressed,
              focusRadius: _sortRadius,
              child: ExcludeSemantics(child: face),
            ),
          ),
        ),
      ),
    );
  }
}
