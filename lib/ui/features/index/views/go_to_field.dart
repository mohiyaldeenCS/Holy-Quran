import 'package:flutter/material.dart' hide Icon, IconButton;

import 'package:holyquran/ui/core/metrics/index_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';

/// A field for a number in the go-to sheet, built like the search field
/// (`.qk-search`): `surface` with a `line-strong` ring, a `primary` ring while
/// it has focus, at least 48 high. It takes digits of any system; what they
/// mean is the view model's to decide. [label] names it for a screen reader
/// and is also shown above it by the sheet.
class GoToField extends StatefulWidget {
  const GoToField({
    required this.controller,
    required this.label,
    required this.onChanged,
    required this.onSubmitted,
    this.autofocus = false,
    this.last = true,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final bool autofocus;

  /// Whether the keyboard's action key submits, rather than moving on.
  final bool last;

  @override
  State<GoToField> createState() => _GoToFieldState();
}

class _GoToFieldState extends State<GoToField> {
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
          borderRadius: IndexMetrics.fieldRadius,
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
            padding: IndexMetrics.fieldPadding,
            // The label is the hint, as the search field's is: the field's own
            // node carries it.
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                controller: widget.controller,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                textInputAction: widget.last
                    ? TextInputAction.done
                    : TextInputAction.next,
                textDirection: TextDirection.rtl,
                onChanged: (_) => widget.onChanged(),
                onSubmitted: (_) => widget.onSubmitted(),
                style: SearchFieldBox.inputStyle.copyWith(color: colors.ink),
                cursorColor: colors.ink,
                decoration: IndexMetrics.fieldDecoration.copyWith(
                  hintText: widget.label,
                  hintStyle: SearchFieldBox.hintStyle(colors.inkMuted),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
