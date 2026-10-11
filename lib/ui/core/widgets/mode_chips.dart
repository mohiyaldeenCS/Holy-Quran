import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/reveal_on_focus.dart';

// .qk-chips: padding 4px 2px, which its margin -4px -2px takes back. The 4px
// above and below stay in the strip and hold the chips' 48 hit area
// (`.qk-chip::after { inset: -4px 0 }`). At the ends the two cancel: the
// chips sit flush with the strip's edges, and only the edge the scrolled
// chips are cut at lies 2px further out.
const double _clipOutset = 2;
const double _hitOutset = AppSpacing.space1;
// .qk-chip: height 40px; border-radius 20px is half of it.
const double _height = 40;
const BorderRadius _radius = BorderRadius.all(Radius.circular(_height / 2));
// .qk-chip: gap 6px.
const double _gap = 6;
// ModeChips in index.jsx: <Icon name="check" size={16} />.
const double _checkSize = 16;

// .qk-chip: font-size 15px; font-weight 500; .is-on: font-weight 600. No line
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

/// The search modes (`ModeChips`, `.qk-chips`): a radio group of chips in a
/// strip that scrolls sideways, the first on the right. One is always
/// selected; it fills with `primary-soft` and carries a check mark, so the
/// choice is not told by colour alone.
///
/// [options] are the modes whose data exists (PRD §7.8); the caller leaves
/// out the rest. The strip is 48 high: the chips' 40 and the 4 above and
/// below that hold their hit area. At rest its first chip is flush with its
/// start, so the caller places it on the content edge.
class ModeChips extends StatelessWidget {
  const ModeChips({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  }) : assert(selectedIndex >= 0 && selectedIndex < options.length);

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    role: SemanticsRole.radioGroup,
    label: AppLocalizations.of(context).searchModesLabel,
    child: ClipRect(
      clipper: const _OutsetClipper(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          spacing: AppSpacing.space2,
          children: [
            for (final (index, option) in options.indexed)
              RevealOnFocus(
                child: _Chip(
                  label: option,
                  selected: index == selectedIndex,
                  onTap: () => onChanged(index),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// The strip's box widened by [_clipOutset] at each end: where the scroll
/// edge of `.qk-chips` lies once its margin has pulled it out.
final class _OutsetClipper extends CustomClipper<Rect> {
  const _OutsetClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-_clipOutset, 0, size.width + _clipOutset, size.height);

  @override
  bool shouldReclip(_OutsetClipper oldClipper) => false;
}

class _Chip extends StatelessWidget {
  const _Chip({
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
    final foreground = selected ? colors.onPrimarySoft : colors.ink;
    // Container adds the 1px border to the padding, as the button's
    // border-box does. .is-on keeps the border's width and makes it
    // transparent: an undrawn side.
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
        spacing: _gap,
        children: [
          if (selected)
            Icon(IconName.check, size: _checkSize, color: foreground),
          // .qk-chip: white-space nowrap; the strip scrolls instead.
          Text(
            label,
            softWrap: false,
            style: _labelStyle.copyWith(
              color: foreground,
              fontWeight: selected ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
    // A radio, not a button, so Pressable's button role does not apply; the
    // gesture, keys, ring and cursor are its parts, as in Switch.
    return Semantics(
      container: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _hitOutset),
          child: FocusRing(
            radius: _radius,
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
      ),
    );
  }
}
