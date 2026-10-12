import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/copy_form.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';

/// The copy sheet (Share.dc.html): a handle, «نسخ الآية», the copy forms as
/// a radio group, and «انسخ».
///
/// [forms] are the forms that can be copied; the caller leaves out the rest.
/// The sheet shows no text of the ayah: what is copied is read from the
/// pack when [onCopy] runs (SH-05). Disabled while [onCopy] is null.
class CopySheet extends StatelessWidget {
  const CopySheet({
    required this.forms,
    required this.selected,
    required this.onSelected,
    required this.onCopy,
    super.key,
  });

  final List<CopyForm> forms;
  final CopyForm selected;
  final ValueChanged<CopyForm> onSelected;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    assert(forms.contains(selected), 'The selected form is not shown.');
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return CopySheetFrame(
      children: [
        Padding(
          padding: _titlePadding,
          child: Semantics(
            header: true,
            child: Text(
              l10n.copySheetTitle,
              style: _titleStyle.copyWith(color: colors.ink),
            ),
          ),
        ),
        Semantics(
          container: true,
          explicitChildNodes: true,
          role: SemanticsRole.radioGroup,
          label: l10n.copySheetTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final form in forms)
                _FormRow(
                  label: _labelOf(form, l10n),
                  selected: form == selected,
                  onTap: () => onSelected(form),
                ),
            ],
          ),
        ),
        CopySheetFrame.action(
          Button(label: l10n.copyAction, onPressed: onCopy),
        ),
      ],
    );
  }
}

/// The copy sheet's frame (Share.dc.html): `surface` with the sheet shadow,
/// rounded top corners, the handle, and [children] a fixed gap apart. The
/// share sheet, which the identity does not draw, takes it too. It scrolls
/// when the screen is shorter than its content.
class CopySheetFrame extends StatelessWidget {
  const CopySheetFrame({required this.children, super.key});

  /// [button] with the space the board sets above the sheet's button.
  static Widget action(Widget button) => Padding(
    padding: const EdgeInsets.only(top: _buttonGap),
    child: button,
  );

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusSheet),
        ),
        boxShadow: context.shadows.shadowSheet,
      ),
      child: SingleChildScrollView(
        // The sheet route keeps no safe area at the bottom; the button stays
        // above the home indicator and the gesture strip.
        // CSS adds the border to the padding; Flutter draws it over the
        // padding, so the content is moved down by its width.
        padding: _padding.copyWith(
          top: _padding.top + _topBorder,
          bottom: _padding.bottom + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: _gap,
          children: [
            Center(
              child: Container(
                width: _handleSize.width,
                height: _handleSize.height,
                decoration: BoxDecoration(
                  color: colors.line,
                  borderRadius: _handleRadius,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

String _labelOf(CopyForm form, AppLocalizations l10n) => switch (form) {
  CopyForm.ayahOnly => l10n.copyAyahOnly,
  CopyForm.withSurah => l10n.copyWithSurah,
  CopyForm.withSurahAndNumber => l10n.copyWithSurahAndNumber,
};

class _FormRow extends StatelessWidget {
  const _FormRow({
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
    final ring = selected ? colors.primary : colors.lineStrong;
    final face = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
      child: Row(
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
          Expanded(
            child: Text(label, style: _labelStyle.copyWith(color: colors.ink)),
          ),
        ],
      ),
    );
    // A radio, not a button, as ModeChips' chips are.
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
            child: ExcludeSemantics(child: face),
          ),
        ),
      ),
    );
  }
}

// Share.dc.html, the copy sheet: `padding:18px 22px 22px;gap:6px`, corners
// `border-radius:28px` (radius-sheet) on #FFFBF2 (surface) with the sheet
// shadow (shadow-sheet). Docked as a bottom sheet, it takes `.qk-sheet`'s top
// corners and `border-top: 1px solid var(--line)`, which keeps its edge in
// the contrast theme, where the shadow is none.
const EdgeInsets _padding = EdgeInsets.fromLTRB(22, 18, 22, 22);
// .qk-sheet: `border-top: 1px`, BorderSide's default width.
const double _topBorder = 1;
const double _gap = 6;

// Share.dc.html, the handle: `width:40px;height:5px;border-radius:3px` in
// #DDD2B8 (line).
const Size _handleSize = Size(40, 5);
const BorderRadius _handleRadius = BorderRadius.all(Radius.circular(3));

// Share.dc.html, the title: `font-size:19px;font-weight:600;
// padding:8px 0 4px`, no line height set.
const EdgeInsets _titlePadding = EdgeInsets.only(
  top: AppSpacing.space2,
  bottom: AppSpacing.space1,
);
const TextStyle _titleStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 19,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

// Share.dc.html, each form: `<label>` with `gap:12px` (space-3),
// `min-height:48px` (target-min), `font-size:16px`, no line height set.
const TextStyle _labelStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 16,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

// Share.dc.html, the radio: `width:22px;height:22px;border-radius:11px;
// border:2px solid`, #0E5A52 (primary) when selected with a
// `width:10px;height:10px` #0E5A52 dot. The unselected ring is #8C9794, which
// no token holds; line-strong is the token of a control's outline.
const double _radioSize = 22;
const double _radioBorder = 2;
const double _dotSize = 10;

// The board's rows have no corners, so neither has their focus ring.
const BorderRadius _rowFocusRadius = BorderRadius.zero;

// Share.dc.html, the button: `margin-top:10px` beyond the column's 6px gap.
const double _buttonGap = 10;
