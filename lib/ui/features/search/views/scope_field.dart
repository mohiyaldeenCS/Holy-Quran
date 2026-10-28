import 'package:flutter/material.dart' hide Icon, IconButton;

import 'package:holyquran/ui/core/metrics/search_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';

/// The field for the number of the surah or juz a search is limited to,
/// built like the search field's box (`.qk-search`) as the go-to sheet's
/// fields are: `surface` with a `line-strong` ring, a `primary` ring while it
/// has focus, at least 48 high. It takes digits of any system; what they mean
/// is the view model's. [label] is its hint and spoken name.
class ScopeField extends StatefulWidget {
  const ScopeField({
    required this.controller,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<ScopeField> createState() => _ScopeFieldState();
}

class _ScopeFieldState extends State<ScopeField> {
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
          borderRadius: SearchMetrics.fieldRadius,
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
            padding: SearchMetrics.fieldPadding,
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                controller: widget.controller,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textDirection: TextDirection.rtl,
                onChanged: widget.onChanged,
                style: SearchFieldBox.inputStyle.copyWith(color: colors.ink),
                cursorColor: colors.ink,
                decoration: SearchMetrics.fieldDecoration.copyWith(
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
