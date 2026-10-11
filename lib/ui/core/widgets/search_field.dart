import 'package:flutter/material.dart' hide Icon, IconButton;

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

// .qk-search: height 56px.
const double _height = 56;
// .qk-search: gap 10px.
const double _gap = 10;
// .qk-search: padding-inline 16px 6px; the start is space-4.
const double _endInset = 6;
// .qk-search: box-shadow inset 0 0 0 1.5px var(--line-strong);
// :focus-within: inset 0 0 0 2px var(--primary).
const double _ringWidth = 1.5;
const double _focusedRingWidth = 2;
// SearchField in index.jsx: <Icon name="search" size={22} />, and the
// microphone's <Icon name="mic" size={22} />, whose place the clear button
// takes (D-089, 5).
const double _iconSize = 22;

// .qk-search-input: font-size 18px; font-weight 600; ::placeholder 400. No
// line height is set, so it is the font's own (CSS `normal`); the style does
// not inherit, so the ambient body line height cannot reach it.
const TextStyle _inputStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 18,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
  textBaseline: TextBaseline.alphabetic,
);

/// The search field (`SearchField`, `.qk-search`): the search icon and the
/// text, 56 high on `surface` with a `line-strong` ring that turns into a
/// 2 px `primary` ring while anything in it has focus. Its hint and spoken
/// name are «ابحث في القرآن»; the keyboard's action key searches.
///
/// The voice button is deferred, so it is not drawn. While the field holds
/// text, a plain 48 clear button stands in its place; when it is empty,
/// nothing does (D-089, 5). Clearing reports the empty text to [onChanged].
class SearchField extends StatefulWidget {
  const SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  bool _focused = false;

  void _onFocusChange(bool focused) {
    if (focused != _focused) setState(() => _focused = focused);
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final input = Material(
      // TextField draws through Material; the field itself has no Material
      // look.
      type: MaterialType.transparency,
      child: TextField(
        controller: widget.controller,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textDirection: TextDirection.rtl,
        textInputAction: TextInputAction.search,
        style: _inputStyle.copyWith(color: colors.ink),
        // .qk-search-input sets no caret-color, so the caret is its ink.
        cursorColor: colors.ink,
        // Not collapsed: the decorator keeps the input at least target-min
        // high, centred, so the text is a 48 target as `.qk-search-input`'s
        // `height: 100%` makes it one.
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: l10n.searchFieldHint,
          hintStyle: _inputStyle.copyWith(
            color: colors.inkMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
    // :focus-within: the clear button's focus turns the ring too.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _onFocusChange,
      child: DecoratedBox(
        // A border drawn inside the box, as an inset box-shadow: no layout.
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.radiusButton),
          border: Border.all(
            color: _focused ? colors.primary : colors.lineStrong,
            width: _focused ? _focusedRingWidth : _ringWidth,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _height),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.space4,
              end: _endInset,
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, field) => Row(
                spacing: _gap,
                children: [
                  Icon(
                    IconName.search,
                    size: _iconSize,
                    color: colors.inkMuted,
                  ),
                  Expanded(
                    child: Semantics(
                      // `aria-label`: the shown hint names the empty field;
                      // once it holds text, the hint is gone and this does.
                      label: value.text.isEmpty ? null : l10n.searchFieldHint,
                      child: field,
                    ),
                  ),
                  if (value.text.isNotEmpty)
                    IconButton(
                      icon: IconName.close,
                      label: l10n.searchFieldClear,
                      iconSize: _iconSize,
                      onPressed: _clear,
                    ),
                ],
              ),
              child: input,
            ),
          ),
        ),
      ),
    );
  }
}
