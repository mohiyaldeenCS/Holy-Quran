import 'package:flutter/material.dart' hide Icon, IconButton;

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';

// The identity has one field, `SearchField` (`.qk-search`), so a field for a
// number takes its box: `radius-button`, `space-4` at the start and the end,
// and the input not collapsed, as the search field's is, so that the
// decorator keeps it at least target-min high.
final BorderRadius _radius = BorderRadius.circular(AppRadius.radiusButton);
const EdgeInsets _padding = EdgeInsets.symmetric(horizontal: AppSpacing.space4);
const InputDecoration _decoration = InputDecoration(
  border: InputBorder.none,
  contentPadding: EdgeInsets.zero,
);

/// A field for a number, built like the search field's box (`.qk-search`):
/// `surface` with a `line-strong` ring, a `primary` ring while it has focus,
/// 56 high (`SearchFieldBox.height`). It takes digits of any system; what
/// they mean is the caller's. [label] is its hint and, once it holds text and
/// the hint is gone, its spoken name.
class NumberField extends StatefulWidget {
  const NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.last = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  /// Whether the keyboard's action key finishes, rather than moving on.
  final bool last;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: _radius,
          border: Border.all(
            color: _focused ? colors.primary : colors.lineStrong,
            width: _focused
                ? SearchFieldBox.focusedRingWidth
                : SearchFieldBox.ringWidth,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SearchFieldBox.height),
          child: Padding(
            padding: _padding,
            child: Material(
              type: MaterialType.transparency,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, field) => Semantics(
                  label: value.text.isEmpty ? null : widget.label,
                  child: field,
                ),
                child: TextField(
                  controller: widget.controller,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  textInputAction: widget.last
                      ? TextInputAction.done
                      : TextInputAction.next,
                  textDirection: TextDirection.rtl,
                  onChanged: widget.onChanged,
                  onSubmitted: (_) => widget.onSubmitted?.call(),
                  style: SearchFieldBox.inputStyle.copyWith(color: colors.ink),
                  cursorColor: colors.ink,
                  decoration: _decoration.copyWith(
                    hintText: widget.label,
                    hintStyle: SearchFieldBox.hintStyle(colors.inkMuted),
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
