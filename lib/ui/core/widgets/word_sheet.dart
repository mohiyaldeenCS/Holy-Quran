import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/reveal_on_focus.dart';

// .qk-sheet: padding var(--space-3) 22px 22px; gap var(--space-4).
const double _sheetSide = 22;
const double _sheetBottom = 22;
// .qk-sheet-handle: width 44px; height 5px; border-radius 3px.
const Size _handleSize = Size(44, 5);
const BorderRadius _handleRadius = BorderRadius.all(Radius.circular(3));
// .qk-sheet-tab: height 40px and border 1px on a `<span>`, which nothing sets
// to border-box, so the border lies outside the 40: 42 in all, selected or
// not (`.is-on` only makes it transparent). border-radius 20px.
const double _tabBorderWidth = 1;
const double _tabHeight = 40 + 2 * _tabBorderWidth;
const BorderRadius _tabRadius = BorderRadius.all(Radius.circular(20));
// Each tab's 48 hit area reaches 3px above and below its 42.
const double _hitOutset = (AppSizes.targetMin - _tabHeight) / 2;
// The tabs scroll like `.qk-chips` (D-087): padding 4px 2px, taken back by
// its margin. The 4px above and below hold the tabs' hit area and keep their
// focus ring, drawn 4px out, inside the strip's clip. At the ends the strip
// is placed 2px out and padded 2px in, so the tabs sit flush with the
// sheet's content and only the edge the scrolled tabs are cut at lies 2px
// further out.
const double _stripInsetX = 2;
const double _stripInsetY = AppSpacing.space1;
// .qk-sheet-rows: border-radius 20px; padding 4px 18px.
const BorderRadius _rowsRadius = BorderRadius.all(Radius.circular(20));
const double _rowsInsetX = 18;
const double _rowsInsetY = AppSpacing.space1;
// .qk-sheet-row: gap var(--space-4).
const double _rowGap = AppSpacing.space4;

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
/// identity's order and scroll sideways, so none is hidden at 200% (D-087);
/// [selectedTab] is one of them.
/// [word] is drawn by [QuranText] in `accent` (D-085), whole on one line:
/// when it and its place do not fit side by side the place goes under it,
/// and a word wider than the sheet is scaled down to fit.
/// [rows] come with the [note] that names their source (WordSheet README).
/// A row with an empty value is not shown, and the note is shown only under
/// the rows that are.
///
/// When [span] is given, [word] is the whole ayah and the word drawn is the
/// slice between the offsets [span] stores for it; the text is never cut
/// anywhere else. [body] is the content of a tab the identity draws no rows
/// for, such as a tafsir passage (docs/DESIGN_SYSTEM.md, "Building a screen
/// the identity does not draw"): it stands under the word, scrolls when it
/// is taller than the screen, and is announced as the tab's panel.
class WordSheet extends StatelessWidget {
  const WordSheet({
    required this.word,
    required this.wordNumber,
    required this.wordCount,
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
    this.span,
    this.rows = const [],
    this.note,
    this.body,
    super.key,
  }) : assert(wordNumber >= 1 && wordNumber <= wordCount),
       assert(tabs.length > 0),
       assert(rows.length == 0 || (note?.length ?? 0) > 0);

  final PackText word;
  final int wordNumber;
  final int wordCount;
  final Set<WordSheetTab> tabs;
  final WordSheetTab selectedTab;
  final ValueChanged<WordSheetTab> onTabSelected;
  final WordSpan? span;
  final List<WordSheetRow> rows;
  final String? note;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    // Here, not in the const constructor, which cannot call a method.
    assert(tabs.contains(selectedTab), 'The selected tab is not shown.');
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
      // The sheet route keeps no safe area at the bottom (as in
      // CopySheetFrame); the content stays above the home indicator.
      padding: EdgeInsets.only(
        top: AppSpacing.space3,
        bottom: _sheetBottom + MediaQuery.viewPaddingOf(context).bottom,
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
          // The strip's 4px insets sit inside the 16px gaps, as `.qk-chips`'
          // margin takes them back.
          const SizedBox(height: gap - _stripInsetY),
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
          const SizedBox(height: gap - _stripInsetY),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _sheetSide),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: [
                _WordLine(
                  // Scaled, never wrapped: a Quran word is drawn whole.
                  word: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: switch (span) {
                      final span? => QuranText.word(
                        word,
                        span,
                        colour: QuranTextColour.accent,
                      ),
                      null => QuranText(
                        word,
                        size: QuranTextSize.focus,
                        align: QuranTextAlign.start,
                        colour: QuranTextColour.accent,
                      ),
                    },
                  ),
                  position: Text(
                    l10n.wordSheetPosition(
                      arabicDigits(wordNumber),
                      arabicDigits(wordCount),
                    ),
                    style: _positionStyle.copyWith(color: colors.inkMuted),
                  ),
                ),
                if (rows.isNotEmpty) ...[
                  _Rows(rows: rows),
                  if (note != null && note.isNotEmpty)
                    Text(
                      note,
                      textAlign: TextAlign.center,
                      style: _noteStyle.copyWith(color: colors.inkMuted),
                    ),
                ],
              ],
            ),
          ),
          if (body case final body?)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  _sheetSide,
                  gap,
                  _sheetSide,
                  0,
                ),
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  role: SemanticsRole.tabPanel,
                  child: body,
                ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: _stripInsetX,
        vertical: _stripInsetY - _hitOutset,
      ),
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
              RevealOnFocus(
                child: _Tab(
                  label: _labelOf(l10n, tab),
                  selected: tab == selected,
                  onTap: () => onSelected(tab),
                ),
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
              child: _SheetRow(
                label: Text(
                  row.label,
                  style: _rowStyle.copyWith(color: colors.inkMuted),
                ),
                value: Text(
                  row.value,
                  // .qk-sheet-row b: text-align left, the row's end.
                  textAlign: TextAlign.end,
                  style: _rowStyle.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _RowPart { label, value }

/// `.qk-sheet-row`: [label] at the start and [value] at the end, both from
/// the row's top (`display: flex; justify-content: space-between`, items
/// stretched), at least [_rowGap] apart.
///
/// The two are laid out as CSS lays out its items (`flex: 0 1 auto;
/// min-width: auto`): each is as wide as its text on one line while the two
/// fit; when they do not, both shrink in proportion to that width, and
/// neither below its longest word, so no word is broken. Where even their
/// longest words do not fit side by side, CSS lets them overflow the row;
/// here both are narrowed further, in proportion to their longest words, and
/// only then is a word broken.
class _SheetRow
    extends SlottedMultiChildRenderObjectWidget<_RowPart, RenderBox> {
  const _SheetRow({required this.label, required this.value});

  final Widget label;
  final Widget value;

  @override
  Iterable<_RowPart> get slots => _RowPart.values;

  @override
  Widget childForSlot(_RowPart slot) => switch (slot) {
    _RowPart.label => label,
    _RowPart.value => value,
  };

  @override
  _RenderSheetRow createRenderObject(BuildContext context) =>
      _RenderSheetRow(Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderSheetRow renderObject) {
    renderObject.textDirection = Directionality.of(context);
  }
}

/// Where the label and value of a row go, and the row's size.
typedef _RowLine = ({Offset label, Offset value, Size size});

class _RenderSheetRow extends RenderBox
    with
        SlottedContainerRenderObjectMixin<_RowPart, RenderBox>,
        _PlacedChildren<_RowPart> {
  _RenderSheetRow(this._textDirection);

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _label => childForSlot(_RowPart.label)!;
  RenderBox get _value => childForSlot(_RowPart.value)!;

  /// The widths the label and the value get on a row [width] wide.
  ({double label, double value}) _widths(double width) {
    final room = math.max(0.0, width - _rowGap);
    final labelMax = _label.getMaxIntrinsicWidth(double.infinity);
    final valueMax = _value.getMaxIntrinsicWidth(double.infinity);
    if (labelMax + valueMax <= room) return (label: labelMax, value: valueMax);
    final labelMin = _label.getMinIntrinsicWidth(double.infinity);
    final valueMin = _value.getMinIntrinsicWidth(double.infinity);
    final double label;
    if (labelMin + valueMin > room) {
      label = room * labelMin / (labelMin + valueMin);
    } else {
      // flex-shrink 1, scaled by the flex basis: each gives up a share of
      // the overflow in proportion to its one-line width; one that would go
      // below its longest word stops there and the other gives up the rest.
      label = clampDouble(
        room * labelMax / (labelMax + valueMax),
        labelMin,
        room - valueMin,
      );
    }
    return (label: label, value: room - label);
  }

  /// The row under [constraints], by [layoutChild]: real and dry layout share
  /// it, so they cannot place the two differently.
  _RowLine _arrange(BoxConstraints constraints, ChildLayouter layoutChild) {
    final width = constraints.maxWidth;
    final widths = _widths(width);
    final label = layoutChild(_label, BoxConstraints(maxWidth: widths.label));
    final value = layoutChild(_value, BoxConstraints(maxWidth: widths.value));
    final (labelX, valueX) = switch (_textDirection) {
      TextDirection.rtl => (width - label.width, 0.0),
      TextDirection.ltr => (0.0, width - value.width),
    };
    return (
      label: Offset(labelX, 0),
      value: Offset(valueX, 0),
      size: constraints.constrain(
        Size(width, math.max(label.height, value.height)),
      ),
    );
  }

  @override
  void performLayout() {
    final row = _arrange(constraints, ChildLayoutHelper.layoutChild);
    (_label.parentData! as BoxParentData).offset = row.label;
    (_value.parentData! as BoxParentData).offset = row.value;
    size = row.size;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, ChildLayoutHelper.dryLayoutChild).size;

  // The row's baseline is its first item's, the label's, at its top.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _label.getDistanceToActualBaseline(baseline);

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => _label.getDryBaseline(
    BoxConstraints(maxWidth: _widths(constraints.maxWidth).label),
    baseline,
  );

  // CSS's min-content and max-content widths of the row: the two side by
  // side, at their longest words and on one line.
  @override
  double computeMinIntrinsicWidth(double height) =>
      _label.getMinIntrinsicWidth(height) +
      _rowGap +
      _value.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _label.getMaxIntrinsicWidth(height) +
      _rowGap +
      _value.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _arrange(
    BoxConstraints(maxWidth: width),
    ChildLayoutHelper.dryLayoutChild,
  ).size.height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);
}

enum _WordPart { word, position }

/// `.qk-sheet-word`: [word] at the start and [position] at the end, on one
/// baseline (`align-items: baseline; justify-content: space-between`). When
/// the two do not fit side by side, [position] goes under [word], at the
/// start, rather than squeezing the word.
class _WordLine
    extends SlottedMultiChildRenderObjectWidget<_WordPart, RenderBox> {
  const _WordLine({required this.word, required this.position});

  final Widget word;
  final Widget position;

  @override
  Iterable<_WordPart> get slots => _WordPart.values;

  @override
  Widget childForSlot(_WordPart slot) => switch (slot) {
    _WordPart.word => word,
    _WordPart.position => position,
  };

  @override
  _RenderWordLine createRenderObject(BuildContext context) =>
      _RenderWordLine(Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderWordLine renderObject) {
    renderObject.textDirection = Directionality.of(context);
  }
}

/// Where the word and its place go on a line, and the line's size.
typedef _Line = ({Offset word, Offset position, Size size});

class _RenderWordLine extends RenderBox
    with
        SlottedContainerRenderObjectMixin<_WordPart, RenderBox>,
        _PlacedChildren<_WordPart> {
  _RenderWordLine(this._textDirection);

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  RenderBox get _word => childForSlot(_WordPart.word)!;
  RenderBox get _position => childForSlot(_WordPart.position)!;

  /// What each child is laid out in: the line's width, at most.
  static BoxConstraints _childConstraints(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth);

  /// The line under [constraints], by [layoutChild] and [baselineOf]: real
  /// and dry layout share it, so they cannot place the two differently.
  _Line _arrange(
    BoxConstraints constraints,
    ChildLayouter layoutChild,
    ChildBaselineGetter baselineOf,
  ) {
    final width = constraints.maxWidth;
    final within = _childConstraints(constraints);
    final word = layoutChild(_word, within);
    final position = layoutChild(_position, within);
    double start(Size child) => switch (_textDirection) {
      TextDirection.rtl => width - child.width,
      TextDirection.ltr => 0,
    };
    double end(Size child) => width - child.width - start(child);

    final Offset wordAt;
    final Offset positionAt;
    if (word.width + position.width > width) {
      wordAt = Offset(start(word), 0);
      positionAt = Offset(start(position), word.height);
    } else {
      final wordBaseline =
          baselineOf(_word, within, TextBaseline.alphabetic) ?? word.height;
      final positionBaseline =
          baselineOf(_position, within, TextBaseline.alphabetic) ??
          position.height;
      final baseline = math.max(wordBaseline, positionBaseline);
      wordAt = Offset(start(word), baseline - wordBaseline);
      positionAt = Offset(end(position), baseline - positionBaseline);
    }
    return (
      word: wordAt,
      position: positionAt,
      size: constraints.constrain(
        Size(
          width,
          math.max(wordAt.dy + word.height, positionAt.dy + position.height),
        ),
      ),
    );
  }

  _Line _dryArrange(BoxConstraints constraints) => _arrange(
    constraints,
    ChildLayoutHelper.dryLayoutChild,
    ChildLayoutHelper.getDryBaseline,
  );

  @override
  void performLayout() {
    final line = _arrange(
      constraints,
      ChildLayoutHelper.layoutChild,
      ChildLayoutHelper.getBaseline,
    );
    (_word.parentData! as BoxParentData).offset = line.word;
    (_position.parentData! as BoxParentData).offset = line.position;
    size = line.size;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _dryArrange(constraints).size;

  // The line's baseline is the word's, which is first in either layout.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final distance = _word.getDistanceToActualBaseline(baseline);
    return distance == null ? null : _offsetOf(_word).dy + distance;
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final distance = _word.getDryBaseline(
      _childConstraints(constraints),
      baseline,
    );
    return distance == null
        ? null
        : _dryArrange(constraints).word.dy + distance;
  }

  // Stacked, the line is as wide as the wider of the two; side by side, as
  // both.
  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _word.getMinIntrinsicWidth(height),
    _position.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _word.getMaxIntrinsicWidth(height) +
      _position.getMaxIntrinsicWidth(height);

  // As high as the line laid out that wide: the word, scaled down or not,
  // decides whether its place goes beside or under it.
  @override
  double computeMinIntrinsicHeight(double width) =>
      _dryArrange(BoxConstraints(maxWidth: width)).size.height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _dryArrange(BoxConstraints(maxWidth: width)).size.height;
}

Offset _offsetOf(RenderBox child) =>
    (child.parentData! as BoxParentData).offset;

/// Paints and hit-tests the children where layout placed them.
mixin _PlacedChildren<S>
    on RenderBox, SlottedContainerRenderObjectMixin<S, RenderBox> {
  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(child, offset + _offsetOf(child));
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final hit = result.addWithPaintOffset(
        offset: _offsetOf(child),
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
