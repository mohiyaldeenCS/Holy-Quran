import 'package:flutter/material.dart' hide Icon, IconButton;

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';

// A note's box shows at least two lines, then grows with its text.
const int _multilineMinLines = 2;

/// A text field in the box of `.qk-search` (`SearchFieldBox`), the one field
/// the identity has: `surface` with a `line-strong` ring, a `primary` ring
/// while it has focus, at least as high as the search field. A [multiline]
/// box shows two lines and grows with its text. [hint] is shown while it is
/// empty and names it for a screen reader.
class TextBox extends StatefulWidget {
  const TextBox({
    required this.controller,
    required this.hint,
    this.multiline = false,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final bool multiline;
  final VoidCallback? onSubmitted;

  @override
  State<TextBox> createState() => _TextBoxState();
}

class _TextBoxState extends State<TextBox> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final multiline = widget.multiline;
    final onSubmitted = widget.onSubmitted;
    final input = Material(
      // TextField draws through Material; the field has no Material look.
      type: MaterialType.transparency,
      child: TextField(
        controller: widget.controller,
        minLines: multiline ? _multilineMinLines : 1,
        maxLines: multiline ? null : 1,
        keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
        textInputAction: multiline
            ? TextInputAction.newline
            : TextInputAction.done,
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
        textDirection: TextDirection.rtl,
        style: SearchFieldBox.inputStyle.copyWith(color: colors.ink),
        cursorColor: colors.ink,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: widget.hint,
          hintStyle: SearchFieldBox.hintStyle(colors.inkMuted),
        ),
      ),
    );
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.radiusButton),
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
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: multiline ? AppSpacing.space3 : 0,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                // The hint names the empty field; once it holds text this does.
                builder: (context, value, field) => Semantics(
                  label: value.text.isEmpty ? null : widget.hint,
                  child: field,
                ),
                child: input,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
