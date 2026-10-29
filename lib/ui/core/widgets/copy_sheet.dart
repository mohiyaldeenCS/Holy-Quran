import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/copy_form.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/radio_row.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

/// The copy sheet (Share.dc.html): a handle, «نسخ الآية», the copy forms as
/// a radio group, a preview of what the selected form copies, and «انسخ».
///
/// [forms] are the forms that can be copied; the caller leaves out the rest.
/// The preview shows [ayah], read from the pack, quoted, followed by the
/// reference of [surahName] and [ayahNumber] when the selected form has one;
/// it is hidden while [ayah] is null. What is copied is read from the pack
/// again when [onCopy] runs, never from the preview (SH-05). Disabled while
/// [onCopy] is null.
class CopySheet extends StatelessWidget {
  const CopySheet({
    required this.forms,
    required this.selected,
    required this.onSelected,
    required this.onCopy,
    this.ayah,
    this.surahName,
    this.ayahNumber,
    super.key,
  }) : assert((surahName == null) == (ayahNumber == null));

  final List<CopyForm> forms;
  final CopyForm selected;
  final ValueChanged<CopyForm> onSelected;
  final VoidCallback? onCopy;
  final PackText? ayah;
  final PackText? surahName;
  final int? ayahNumber;

  @override
  Widget build(BuildContext context) {
    assert(forms.contains(selected), 'The selected form is not shown.');
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final ayah = this.ayah;
    return CopySheetFrame(
      children: [
        CopySheetTitle(l10n.copySheetTitle),
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
                RadioRow(
                  label: _labelOf(form, l10n),
                  selected: form == selected,
                  onTap: () => onSelected(form),
                  child: Text(
                    _labelOf(form, l10n),
                    style: RadioRow.labelStyle.copyWith(color: colors.ink),
                  ),
                ),
            ],
          ),
        ),
        if (ayah != null)
          _Preview(ayah: ayah, surahName: surahName, ayahNumber: ayahNumber),
        CopySheetFrame.action(
          Button(label: l10n.copyAction, onPressed: onCopy),
        ),
      ],
    );
  }
}

/// What the selected form copies: the ayah between the format's brackets,
/// and the reference after it.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.ayah,
    required this.surahName,
    required this.ayahNumber,
  });

  final PackText ayah;
  final PackText? surahName;
  final int? ayahNumber;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final surahName = this.surahName;
    return Padding(
      padding: const EdgeInsets.only(top: _previewGap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.ground,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(AppRadius.radiusButton),
        ),
        child: Padding(
          padding: _previewPadding,
          child: QuranText.quoted(
            ayah,
            after: surahName == null
                ? null
                : SurahName.span(
                    surahName,
                    format: SurahNameFormat.copyReference,
                    ayah: ayahNumber,
                    style: _referenceStyle.copyWith(color: colors.inkMuted),
                    l10n: AppLocalizations.of(context),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The title of a sheet on [CopySheetFrame], as Share.dc.html draws it: 19
/// semibold on `ink`, with the board's padding, announced as a heading.
class CopySheetTitle extends StatelessWidget {
  const CopySheetTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: _titlePadding,
    child: Semantics(
      header: true,
      child: Text(text, style: _titleStyle.copyWith(color: context.colors.ink)),
    ),
  );
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

// Share.dc.html l.54, the preview: `margin-top:6px` beyond the column's 6px
// gap; `border-radius:16px` (radius-button) on #F8F2E4 (ground) with
// `border:1px solid #DDD2B8` (line); `padding:12px 14px`, 12 being space-3.
// CSS adds the border to the padding; Flutter draws it over the padding, so
// the padding grows by its width.
const double _previewGap = 6;
const double _previewBorder = 1;
const EdgeInsets _previewPadding = EdgeInsets.symmetric(
  vertical: AppSpacing.space3 + _previewBorder,
  horizontal: 14 + _previewBorder,
);

// Share.dc.html l.54, the reference: `font-size:15px` in #51605D
// (ink-muted), no weight or line height set, the space between the two
// spans included.
const TextStyle _referenceStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 15,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

// Share.dc.html, the button: `margin-top:10px` beyond the column's 6px gap.
const double _buttonGap = 10;
