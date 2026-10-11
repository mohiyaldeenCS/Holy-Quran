import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

// .qk-result: border-radius 20px; padding 12px 16px 14px; gap 4px. The top
// and side paddings are space-3 and space-4, the gap space-1.
const BorderRadius _radius = BorderRadius.all(Radius.circular(20));
const double _bottomInset = 14;
// .qk-result-actions: gap 2px.
const double _actionsGap = 2;
// SearchResult in index.jsx: <IconButton … iconSize={22} />.
const double _actionIconSize = 22;
// .qk-result-body.is-clamped: max-height 92px, the concrete value, which
// decides over the README's «نحو ثلاثة أسطر». It grows by the factor the text
// scaler gives the ayah's own size, so a clamp keeps its share of the ayah at
// any text size. A non-linear scaler (Android 14 and later) grows a size of
// 92 far less than the ayah's 22, so it does not scale 92 itself.
const double _clampHeight = 92;
// .qk-result-fade: height 40px, fixed in the reference.
const double _fadeHeight = 40;
// .qk-result-more: min-height 32px; ::after inset -8px 0, a 48 hit area.
const double _moreHeight = 32;
const double _moreHitOutset = 8;
// The link's 48 reaches 8 under the 32 it draws, into the card's bottom
// padding, so a clamped card keeps only the rest of it; an ayah that turns
// out to fit gives those 8 back under itself.
const double _clampedBottomInset = _bottomInset - _moreHitOutset;

// The screen reader's order (AX-01, as in AyahRow): the reference, the ayah
// with its link, then the actions.
const double _referenceOrder = 0;
const double _ayahOrder = 1;
const double _actionsOrder = 2;

// No line height is set in `.qk-result*`, so each is the font's own (CSS
// `normal`); the styles do not inherit, so the ambient body line height
// cannot reach them.
// .qk-result-ref: font-size 15px; font-weight 600.
const TextStyle _referenceStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 15,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-result-more: font-size 14px; font-weight 600.
const TextStyle _moreStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

/// One search result (`SearchResult`, `.qk-result`): the surah name with the
/// ayah number, the context and open-in-the-mushaf buttons, and the ayah in
/// the compact Quran size, on a `surface` card.
///
/// [ayahText] is one whole ayah from the pack, with no inline marker and no
/// match highlight (D-087, D-088). With [clamp], an ayah laid out taller than
/// 92 px, grown as the ayah's text is, is cut there under a 40 px fade, with
/// a link that shows it whole; one that fits is shown whole as without
/// [clamp]. A screen reader always gets the whole ayah, after the reference
/// and before the actions (AX-01).
class SearchResult extends StatefulWidget {
  const SearchResult({
    required this.surahName,
    required this.ayahNumber,
    required this.ayahText,
    required this.onContext,
    required this.onOpen,
    this.clamp = false,
    super.key,
  });

  final PackText surahName;
  final int ayahNumber;
  final PackText ayahText;
  final VoidCallback onContext;
  final VoidCallback onOpen;
  final bool clamp;

  @override
  State<SearchResult> createState() => _SearchResultState();
}

class _SearchResultState extends State<SearchResult> {
  bool _whole = false;
  final _cutFocus = _CutFocusNode();

  @override
  void didUpdateWidget(SearchResult oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ayahText != widget.ayahText) _whole = false;
  }

  @override
  void dispose() {
    _cutFocus.dispose();
    super.dispose();
  }

  /// [_clampHeight] grown by the factor the text scaler gives the compact
  /// Quran size.
  double _clampAt(BuildContext context) {
    const compact = QuranText.compactFontSize;
    return _clampHeight *
        MediaQuery.textScalerOf(context).scale(compact) /
        compact;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final clamped = widget.clamp && !_whole;
    final ayah = QuranText(
      widget.ayahText,
      size: QuranTextSize.compact,
      align: QuranTextAlign.start,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      // Container adds the 1px border to the padding, as CSS does.
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.line),
          borderRadius: _radius,
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space4,
          AppSpacing.space3,
          AppSpacing.space4,
          clamped ? _clampedBottomInset : _bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // .qk-result-top: align-items center; space-between.
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    sortKey: const OrdinalSortKey(_referenceOrder),
                    child: SurahName(
                      widget.surahName,
                      format: SurahNameFormat.withAyah,
                      ayah: widget.ayahNumber,
                      style: _referenceStyle.copyWith(color: colors.primary),
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  sortKey: const OrdinalSortKey(_actionsOrder),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: _actionsGap,
                    children: [
                      IconButton(
                        icon: IconName.context,
                        label: l10n.searchResultContext,
                        iconSize: _actionIconSize,
                        onPressed: widget.onContext,
                      ),
                      IconButton(
                        icon: IconName.mushaf,
                        label: l10n.searchResultOpen,
                        iconSize: _actionIconSize,
                        onPressed: widget.onOpen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space1),
            Semantics(
              container: true,
              sortKey: const OrdinalSortKey(_ayahOrder),
              child: clamped
                  ? _Clamp(
                      height: _clampAt(context),
                      cutFocus: _cutFocus,
                      ayah: ayah,
                      cut: _Cut(
                        label: l10n.searchResultShowWhole,
                        onPressed: () => setState(() => _whole = true),
                      ),
                    )
                  : ayah,
            ),
          ],
        ),
      ),
    );
  }
}

enum _ClampPart { ayah, cut }

/// The focus node over a cut ayah's fade and link. What is under it can take
/// focus only while the clamp shows it, which the clamp learns at layout and
/// sets in [shown]; focus traversal reads it when it runs, so nothing is
/// rebuilt for it.
final class _CutFocusNode extends FocusNode {
  _CutFocusNode() : super(canRequestFocus: false, skipTraversal: true);

  bool shown = false;

  @override
  bool get descendantsAreFocusable => shown && super.descendantsAreFocusable;
}

/// `.qk-result-body.is-clamped`: [ayah] laid out whole, then shown whole if
/// it fits in [height], or else cut at [height] with [cut] laid over its last
/// [_fadeHeight] and below it.
///
/// Whether the ayah fits is known only once it is laid out, so [cut] is
/// always built and laid out, and shown only under a cut ayah: painted, hit,
/// read and focusable then and only then. One frame, and no link or fade for
/// an ayah that fits.
class _Clamp
    extends SlottedMultiChildRenderObjectWidget<_ClampPart, RenderBox> {
  const _Clamp({
    required this.height,
    required this.cutFocus,
    required this.ayah,
    required this.cut,
  });

  final double height;
  final _CutFocusNode cutFocus;
  final Widget ayah;
  final Widget cut;

  @override
  Iterable<_ClampPart> get slots => _ClampPart.values;

  @override
  Widget childForSlot(_ClampPart slot) => switch (slot) {
    _ClampPart.ayah => ayah,
    _ClampPart.cut => Focus.withExternalFocusNode(
      focusNode: cutFocus,
      includeSemantics: false,
      child: cut,
    ),
  };

  @override
  _ClampElement createElement() => _ClampElement(this);

  @override
  _RenderClamp createRenderObject(BuildContext context) =>
      _RenderClamp(height, cutFocus);

  @override
  void updateRenderObject(BuildContext context, _RenderClamp renderObject) {
    renderObject
      ..height = height
      ..cutFocus = cutFocus;
  }
}

/// Counts the cut as offstage while the ayah fits, as [Offstage] does, so
/// that finders and the inspector see what is shown.
class _ClampElement extends SlottedRenderObjectElement<_ClampPart, RenderBox> {
  _ClampElement(_Clamp super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final cutShown = (renderObject as _RenderClamp)._isCut;
    visitChildren((child) {
      if (cutShown || child.slot == _ClampPart.ayah) visitor(child);
    });
  }
}

class _RenderClamp extends RenderBox
    with SlottedContainerRenderObjectMixin<_ClampPart, RenderBox> {
  _RenderClamp(this._height, this._cutFocus);

  double _height;
  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  _CutFocusNode _cutFocus;
  set cutFocus(_CutFocusNode value) {
    if (value == _cutFocus) return;
    _cutFocus = value;
    markNeedsLayout();
  }

  bool _isCut = false;
  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  RenderBox get _ayah => childForSlot(_ClampPart.ayah)!;
  RenderBox get _cut => childForSlot(_ClampPart.cut)!;
  Offset get _cutOffset => (_cut.parentData! as BoxParentData).offset;
  Rect get _shown => Offset.zero & Size(size.width, _height);

  bool _cuts(double ayahHeight) => ayahHeight > _height;

  /// The clamp's height over an ayah [ayahHeight] high, with [cutHeight]
  /// asked only for a cut ayah. Layout, dry layout and the intrinsic heights
  /// all take it from here.
  double _heightOver(double ayahHeight, double Function() cutHeight) =>
      _cuts(ayahHeight)
      ? _height - _fadeHeight + cutHeight()
      : ayahHeight + _bottomInset - _clampedBottomInset;

  @override
  void performLayout() {
    final width = constraints.widthConstraints();
    _ayah.layout(width, parentUsesSize: true);
    // Laid out and placed even when hidden, so that whatever asks where it
    // is, as focus traversal does, gets an answer.
    _cut.layout(width, parentUsesSize: true);
    (_cut.parentData! as BoxParentData).offset = Offset(
      0,
      _height - _fadeHeight,
    );
    _isCut = _cuts(_ayah.size.height);
    size = constraints.constrain(
      Size(
        constraints.maxWidth,
        _heightOver(_ayah.size.height, () => _cut.size.height),
      ),
    );
    _cutFocus.shown = _isCut;
    if (!_isCut && _cutFocus.hasFocus) {
      // The link went out of view with focus on it: focus goes back to the
      // control focused before it, if any, so a keyboard user keeps their
      // place in a list of results.
      final cutFocus = _cutFocus;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!cutFocus.shown) {
          cutFocus.unfocus(
            disposition: UnfocusDisposition.previouslyFocusedChild,
          );
        }
      });
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final width = constraints.widthConstraints();
    return constraints.constrain(
      Size(
        constraints.maxWidth,
        _heightOver(
          _ayah.getDryLayout(width).height,
          () => _cut.getDryLayout(width).height,
        ),
      ),
    );
  }

  // The ayah starts at the top, so its first baseline is the clamp's.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _ayah.getDistanceToActualBaseline(baseline);

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => _ayah.getDryBaseline(constraints.widthConstraints(), baseline);

  // Both children span the clamp, and where the ayah is cut the link shows
  // too, so the clamp needs the wider of the two.
  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _ayah.getMinIntrinsicWidth(height),
    _cut.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    _ayah.getMaxIntrinsicWidth(height),
    _cut.getMaxIntrinsicWidth(height),
  );

  @override
  double computeMinIntrinsicHeight(double width) => _heightOver(
    _ayah.getMinIntrinsicHeight(width),
    () => _cut.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _heightOver(
    _ayah.getMaxIntrinsicHeight(width),
    () => _cut.getMaxIntrinsicHeight(width),
  );

  @override
  bool paintsChild(RenderBox child) => _isCut || child == _ayah;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(_ayah);
    if (_isCut) visitor(_cut);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_isCut) {
      _clip.layer = null;
      context.paintChild(_ayah, offset);
      return;
    }
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      _shown,
      (context, offset) => context.paintChild(_ayah, offset),
      oldLayer: _clip.layer,
    );
    context.paintChild(_cut, offset + _cutOffset);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _isCut && child == _ayah ? _shown : null;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_isCut) {
      final onCut = result.addWithPaintOffset(
        offset: _cutOffset,
        position: position,
        hitTest: (result, transformed) =>
            _cut.hitTest(result, position: transformed),
      );
      if (onCut) return true;
      if (!_shown.contains(position)) return false;
    }
    return _ayah.hitTest(result, position: position);
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

/// What a cut ayah shows over and under its end: `.qk-result-fade` over its
/// last 40 px, and `.qk-result-more` 4 px under it, whose 48 target reaches
/// 8 px up into the gap and the fade.
class _Cut extends StatelessWidget {
  const _Cut({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final surface = context.colors.surface;
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: _fadeHeight,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: DecoratedBox(
                // linear-gradient(to bottom, transparent, var(--surface)).
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [surface.withValues(alpha: 0), surface],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            top: _fadeHeight + AppSpacing.space1 - _moreHitOutset,
          ),
          child: _ShowWhole(label: label, onPressed: onPressed),
        ),
      ],
    );
  }
}

/// `.qk-result-more`: the link under a cut ayah, at the row's start. Its 48
/// hit area reaches 8 px above and below the 32 it draws, as the reference's
/// `::after` does.
class _ShowWhole extends StatelessWidget {
  const _ShowWhole({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static const BorderRadius _focusRadius = BorderRadius.zero;

  @override
  Widget build(BuildContext context) {
    final face = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _moreHeight),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        child: Text(
          label,
          style: _moreStyle.copyWith(color: context.colors.primary),
        ),
      ),
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        container: true,
        label: label,
        // Pressable covers the drawn face, where the focus ring goes; this
        // detector makes the rest of the 48 press it too.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: _moreHitOutset),
            child: Pressable(
              onPressed: onPressed,
              focusRadius: _focusRadius,
              child: ExcludeSemantics(child: face),
            ),
          ),
        ),
      ),
    );
  }
}
