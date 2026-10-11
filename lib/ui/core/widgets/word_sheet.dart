import 'package:flutter/semantics.dart' show SemanticsRole;
import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

// .qk-sheet: padding var(--space-3) 22px 22px; gap var(--space-4).
const double _sheetSide = 22;
const double _sheetBottom = 22;
// .qk-sheet-handle: width 44px; height 5px; border-radius 3px.
const Size _handleSize = Size(44, 5);
const BorderRadius _handleRadius = BorderRadius.all(Radius.circular(3));
// The tabs scroll like `.qk-chips` (D-087): padding 4px 2px, taken back by
// its margin. The 4px above and below hold the tabs' 48 hit area; the 2px at
// the ends keep the focus ring off the scroll edge.
const double _stripInsetX = 2;
const double _hitOutset = AppSpacing.space1;
// .qk-sheet-tab: height 40px; border-radius 20px is half of it.
const double _tabHeight = 40;
const BorderRadius _tabRadius = BorderRadius.all(
  Radius.circular(_tabHeight / 2),
);
// .qk-sheet-rows: border-radius 20px; padding 4px 18px.
const BorderRadius _rowsRadius = BorderRadius.all(Radius.circular(20));
const double _rowsInsetX = 18;
const double _rowsInsetY = AppSpacing.space1;

// No line height is set in `.qk-sheet*`, so each is the font's own (CSS
// `normal`); the styles do not inherit, so the ambient body line height
// cannot reach them.
// .qk-sheet-tab: font-size 15px, the body's 400; .is-on: font-weight 700.
const TextStyle _tabStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 15,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-sheet-pos: font-size 13px.
const TextStyle _positionStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-sheet-row: font-size 16px; `span` 400, `b` font-weight 600.
const TextStyle _rowStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 16,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-sheet-note: font-size 12px.
const TextStyle _noteStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The tabs of the word sheet, in the identity's order.
enum WordSheetTab { text, tafsir, irab, sarf, tajweed }

/// One «label · value» row of [WordSheet].
@immutable
final class WordSheetRow {
  const WordSheetRow(this.label, this.value);

  final String label;
  final String value;
}

/// The word sheet's content (`WordSheet`, `.qk-sheet`): the handle, the tabs,
/// the word with its place in the ayah, the rows and the source [note], on a
/// `surface` sheet rounded at the top. The modal route around it is the
/// caller's.
///
/// [tabs] are those whose pack is installed (PRD §7.8); they are shown in the
/// identity's order and scroll sideways, so none is hidden at 200% (D-087).
/// [word] is drawn by [QuranText] in `accent` (D-085). Rows with an empty
/// value, an empty [rows] and a null or empty [note] show nothing.
class WordSheet extends StatelessWidget {
  const WordSheet({
    required this.word,
    required this.wordNumber,
    required this.wordCount,
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
    this.rows = const [],
    this.note,
    super.key,
  }) : assert(wordNumber >= 1 && wordNumber <= wordCount),
       assert(tabs.length > 0);

  final PackText word;
  final int wordNumber;
  final int wordCount;
  final Set<WordSheetTab> tabs;
  final WordSheetTab selectedTab;
  final ValueChanged<WordSheetTab> onTabSelected;
  final List<WordSheetRow> rows;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final rows = [
      for (final row in this.rows)
        if (row.value.isNotEmpty) row,
    ];
    final note = this.note;
    const gap = AppSpacing.space4;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusSheet),
        ),
        boxShadow: context.shadows.shadowSheet,
      ),
      padding: const EdgeInsets.only(
        top: AppSpacing.space3,
        bottom: _sheetBottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: _handleSize.width,
              height: _handleSize.height,
              decoration: BoxDecoration(
                color: colors.lineStrong,
                borderRadius: _handleRadius,
              ),
            ),
          ),
          // The strip's 4px hit outset sits inside the 16px gaps.
          const SizedBox(height: gap - _hitOutset),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _sheetSide - _stripInsetX,
            ),
            child: _Tabs(
              tabs: [
                for (final tab in WordSheetTab.values)
                  if (tabs.contains(tab)) tab,
              ],
              selected: selectedTab,
              onSelected: onTabSelected,
            ),
          ),
          const SizedBox(height: gap - _hitOutset),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _sheetSide),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: [
                // .qk-sheet-word: align-items baseline; space-between.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: QuranText(
                        word,
                        size: QuranTextSize.focus,
                        align: QuranTextAlign.start,
                        colour: QuranTextColour.accent,
                      ),
                    ),
                    Text(
                      l10n.wordSheetPosition(
                        arabicDigits(wordNumber),
                        arabicDigits(wordCount),
                      ),
                      style: _positionStyle.copyWith(color: colors.inkMuted),
                    ),
                  ],
                ),
                if (rows.isNotEmpty) _Rows(rows: rows),
                if (note != null && note.isNotEmpty)
                  Text(
                    note,
                    textAlign: TextAlign.center,
                    style: _noteStyle.copyWith(color: colors.inkMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<WordSheetTab> tabs;
  final WordSheetTab selected;
  final ValueChanged<WordSheetTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: _stripInsetX),
      // The tablist sits inside the scroll view, so its direct children are
      // the tabs, as the role requires.
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        role: SemanticsRole.tabBar,
        child: Row(
          spacing: AppSpacing.space2,
          children: [
            for (final tab in tabs)
              _Tab(
                label: _labelOf(l10n, tab),
                selected: tab == selected,
                onTap: () => onSelected(tab),
              ),
          ],
        ),
      ),
    );
  }
}

String _labelOf(AppLocalizations l10n, WordSheetTab tab) => switch (tab) {
  WordSheetTab.text => l10n.wordSheetTabText,
  WordSheetTab.tafsir => l10n.wordSheetTabTafsir,
  WordSheetTab.irab => l10n.wordSheetTabIrab,
  WordSheetTab.sarf => l10n.wordSheetTabSarf,
  WordSheetTab.tajweed => l10n.wordSheetTabTajweed,
};

class _Tab extends StatelessWidget {
  const _Tab({
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
    // .is-on keeps the border's width and makes it transparent: an undrawn
    // side. Container adds the 1px border to the padding.
    final face = Container(
      constraints: const BoxConstraints(minHeight: _tabHeight),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? colors.primary : null,
        border: Border.all(
          color: colors.line,
          style: selected ? BorderStyle.none : BorderStyle.solid,
        ),
        borderRadius: _tabRadius,
      ),
      child: Text(
        label,
        softWrap: false,
        style: _tabStyle.copyWith(
          color: selected ? colors.onPrimary : colors.inkMuted,
          fontWeight: selected ? FontWeight.w700 : null,
        ),
      ),
    );
    // A tab, not a button, so Pressable's button role does not apply; the
    // gesture, keys, ring and cursor are its parts, as in Switch.
    return Semantics(
      container: true,
      role: SemanticsRole.tab,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _hitOutset),
          child: FocusRing(
            radius: _tabRadius,
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

class _Rows extends StatelessWidget {
  const _Rows({required this.rows});

  final List<WordSheetRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSunk,
        border: Border.all(color: colors.line),
        borderRadius: _rowsRadius,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: _rowsInsetX,
        vertical: _rowsInsetY,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, row) in rows.indexed)
            Container(
              // .qk-sheet-row: padding var(--space-3) 0; a line under every
              // row but the last.
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space3),
              decoration: index == rows.length - 1
                  ? null
                  : BoxDecoration(
                      border: Border(bottom: BorderSide(color: colors.line)),
                    ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                spacing: AppSpacing.space4,
                children: [
                  Flexible(
                    child: Text(
                      row.label,
                      style: _rowStyle.copyWith(color: colors.inkMuted),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      row.value,
                      // .qk-sheet-row b: text-align left, the row's end.
                      textAlign: TextAlign.end,
                      style: _rowStyle.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
