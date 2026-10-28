import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/reader_paragraph.dart';
import 'package:holyquran/ui/core/reader/reader_style.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

// .qk-sheet: border-top 1px solid var(--line); padding var(--space-3) 22px
// 22px; gap var(--space-4). .qk-ctx overrides the gap with 14px and the bottom
// padding with 24px. CSS adds the border to the padding; Flutter draws it
// over the padding, so the top grows by its width.
const double _topBorder = 1;
const double _sheetSide = 22;
const double _sheetBottom = 24;
const double _gap = 14;
// .qk-sheet-handle: width 44px; height 5px; border-radius 3px.
const Size _handleSize = Size(44, 5);
const BorderRadius _handleRadius = BorderRadius.all(Radius.circular(3));
// The room the sheet leaves above itself. The identity draws the sheet at its
// content's height and no top room, so the value is a spacing token chosen to
// keep a strip of what lies under the scrim visible when a long passage fills
// the sheet.
const double _topRoom = AppSpacing.space7;

// .qk-ctx-title: font-size 20px; font-weight 700. No line height is set, so it
// is the font's own (CSS `normal`); the styles do not inherit, so the ambient
// body line height cannot reach them.
const TextStyle _titleStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 20,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-ctx-title small: font-size 13px; font-weight 400.
const TextStyle _subtitleStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// .qk-ctx-ref: Reem Kufi, font-size 20px; font-weight 600.
const TextStyle _referenceStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.kufi,
  fontFamilyFallback: [AppFonts.sans],
  fontSize: 20,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);

// .qk-ctx .qk-quran-compact: font-size 23px, where `quran-page` is 25. The
// text is set by the surah-mode engine (D-088), whose style is `quran-page`,
// so it is scaled by their ratio: 23 at the system's size. The line height is
// the engine's 2.3, where the sheet's is 2.2.
const double _textSize = 23;
final double _textStep = _textSize / AppTextStyles.quranPage.fontSize!;

// .qk-hl-select: border-radius var(--radius-sm); padding 0 4px;
// box-shadow inset 0 0 0 1.5px var(--selection-line).
const double _selectionInset = 4;
const double _selectionRing = 1.5;

// .qk-ctx-actions: gap 10px.
const double _actionsGap = 10;
// .qk-ctx-play: width and height 52px; border-radius var(--radius-button);
// box-shadow inset 0 0 0 1.5px var(--primary); Icon size 22.
const double _playSize = 52;
const double _playRing = 1.5;
const double _playIconSize = 22;

// The screen reader's order (AX-01): each ayah, then its marker, as in the
// reader.
int _order(int ayah) => 3 * ayah;

/// The ayat a [ContextSheet] shows: [ayat] from ayah [firstAyah] of surah
/// [surah], each with its stored word and mark spans, of which
/// [selectedAyah] is the one asked for.
final class ContextPassage {
  ContextPassage({
    required String riwaya,
    required int surah,
    required this.firstAyah,
    required List<AyahText> ayat,
    required this.selectedAyah,
  }) : assert(selectedAyah >= firstAyah),
       assert(selectedAyah < firstAyah + ayat.length),
       text = SurahText(riwaya: riwaya, surah: surah, ayat: ayat);

  /// The number of the first ayah, in its surah.
  final int firstAyah;
  final int selectedAyah;

  /// The ayat numbered from 1, as the engine takes them; its marker numbers
  /// are those of [firstAyah] on.
  final SurahText text;

  /// The ayah's place in [text].
  int get _selectedIndex => selectedAyah - firstAyah + 1;
}

/// The ayah-context sheet (`ContextSheet`, `.qk-sheet.qk-ctx`): a handle, the
/// title «سياق الآية» over its subtitle with the reference to the ayah, the
/// choice of how much to show, the ayat between their markers with the one
/// asked for framed, and «افتح في المصحف» with an optional play button.
///
/// [amounts] are the labels of the choice, [amount] the one chosen. [passage]
/// is the ayat for it, or null while they are being read. It is set by the
/// surah-mode engine at 23 px, so it justifies as the reference does and
/// centres its last line (D-088); long passages scroll. The play button is not
/// shown without [onPlay].
class ContextSheet extends StatelessWidget {
  const ContextSheet({
    required this.surahName,
    required this.ayahNumber,
    required this.amounts,
    required this.amount,
    required this.onAmountSelected,
    required this.passage,
    required this.onOpen,
    this.onPlay,
    super.key,
  }) : assert(amount >= 0 && amount < amounts.length);

  final PackText surahName;
  final int ayahNumber;
  final List<String> amounts;
  final int amount;
  final ValueChanged<int> onAmountSelected;
  final ContextPassage? passage;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final passage = this.passage;
    final onPlay = this.onPlay;
    final media = MediaQuery.of(context);
    final padding = EdgeInsets.fromLTRB(
      _sheetSide,
      AppSpacing.space3 + _topBorder,
      _sheetSide,
      _sheetBottom + media.viewPadding.bottom,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusSheet),
        ),
        boxShadow: context.shadows.shadowSheet,
      ),
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: media.size.height - _topRoom - padding.vertical,
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
                    color: colors.lineStrong,
                    borderRadius: _handleRadius,
                  ),
                ),
              ),
              // .qk-ctx-head: align-items baseline; justify-content
              // space-between.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                spacing: AppSpacing.space3,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.searchResultContext,
                            style: _titleStyle.copyWith(color: colors.ink),
                          ),
                        ),
                        Text(
                          l10n.contextSubtitle,
                          style: _subtitleStyle.copyWith(
                            color: colors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SurahName(
                      surahName,
                      format: SurahNameFormat.withAyah,
                      ayah: ayahNumber,
                      style: _referenceStyle.copyWith(color: colors.primary),
                    ),
                  ),
                ],
              ),
              LevelSwitch(
                options: amounts,
                selectedIndex: amount,
                onChanged: onAmountSelected,
                semanticLabel: l10n.contextAmountLabel,
              ),
              if (passage != null) Flexible(child: _ContextText(passage)),
              Row(
                spacing: _actionsGap,
                children: [
                  Expanded(
                    child: Button(
                      label: l10n.searchResultOpen,
                      onPressed: onOpen,
                    ),
                  ),
                  if (onPlay != null)
                    _PlayButton(
                      label: l10n.contextPlayFromAyah,
                      onPressed: onPlay,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.qk-ctx-play`: a square button with a `primary` ring and the play icon.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  static final BorderRadius _radius = BorderRadius.circular(
    AppRadius.radiusButton,
  );

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return Semantics(
      container: true,
      label: label,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: _radius,
        child: ExcludeSemantics(
          child: Container(
            width: _playSize,
            height: _playSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: _radius,
              border: Border.all(color: primary, width: _playRing),
            ),
            child: Icon(IconName.play, size: _playIconSize, color: primary),
          ),
        ),
      ),
    );
  }
}

/// The passage in the surah-mode engine's blocks (D-088), the same plan the
/// reader uses at a smaller size, with each ayah's marker numbered as in its
/// surah and the asked-for ayah framed. Each block is laid out when it comes
/// near the viewport, so a whole surah opens without laying out all its text.
final class _ContextText extends StatefulWidget {
  const _ContextText(this.passage);

  final ContextPassage passage;

  @override
  State<_ContextText> createState() => _ContextTextState();
}

final class _ContextTextState extends State<_ContextText> {
  ReaderStyle? _style;
  SurahLayout? _layout;
  Widget? _list;

  // SliverLayoutBuilder builds again on every scroll offset; returning the
  // same list while the plan holds lets Flutter skip the blocks.
  Widget _listFor(double width, TextScaler scaler) {
    final style = _style?.scaler == scaler
        ? _style!
        : _style = ReaderStyle(scaler);
    final text = widget.passage.text;
    final last = _layout;
    if (last != null &&
        identical(last.text, text) &&
        last.style == style &&
        last.width == width) {
      return _list ??= _buildList(last);
    }
    final layout = _layout = SurahLayout.plan(text, style, width);
    return _list = _buildList(layout);
  }

  Widget _buildList(SurahLayout layout) => SliverVariedExtentList.builder(
    itemCount: layout.blocks.length,
    itemExtentBuilder: (index, _) =>
        index < layout.blocks.length ? layout.blockHeight(index) : null,
    itemBuilder: (context, index) => _BlockHost(
      key: ValueKey((layout, index)),
      layout: layout,
      index: index,
      passage: widget.passage,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.textScalerOf(context);
    return CustomScrollView(
      shrinkWrap: true,
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) => _listFor(
            constraints.crossAxisExtent,
            ReaderTextScaler(system, _textStep),
          ),
        ),
      ],
    );
  }
}

/// Lays a block out while it is built, in the theme's `quran-ink`, and frees
/// its paragraphs when it goes.
final class _BlockHost extends StatefulWidget {
  const _BlockHost({
    required this.layout,
    required this.index,
    required this.passage,
    super.key,
  });

  final SurahLayout layout;
  final int index;
  final ContextPassage passage;

  @override
  State<_BlockHost> createState() => _BlockHostState();
}

final class _BlockHostState extends State<_BlockHost> {
  BlockLayout? _block;

  BlockLayout _blockIn(Color ink) {
    final block = _block;
    if (block != null && block.ink == ink) return block;
    block?.dispose();
    return _block = BlockLayout(widget.layout, widget.index, ink: ink);
  }

  @override
  void dispose() {
    _block?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ContextBlock(_blockIn(context.colors.quranInk), widget.passage);
}

/// One laid-out block: its text, the frame behind the asked-for ayah, and
/// each ayah's `AyahMarker` in its slot. A screen reader reads each ayah, then
/// its marker, and hears which ayah is the one asked for.
final class _ContextBlock extends StatelessWidget {
  const _ContextBlock(this.layout, this.passage);

  final BlockLayout layout;
  final ContextPassage passage;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: layout.plan.style.scaler),
      child: SizedBox(
        width: layout.width,
        height: layout.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BlockPainter(
                  layout,
                  passage._selectedIndex,
                  fill: colors.selection,
                  line: colors.selectionLine,
                ),
              ),
            ),
            for (final ayah in layout.ayat) ...[
              Positioned.fromRect(
                rect: layout.ayahRect(ayah)!,
                child: _ayah(ayah),
              ),
              Positioned.fromRect(
                rect: layout.markerRect(ayah)!,
                child: Semantics(
                  container: true,
                  sortKey: OrdinalSortKey(_order(ayah) + 1.0),
                  child: AyahMarker(number: passage.firstAyah + ayah - 1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ayah(int ayah) {
    final reading = ayahSemantics(
      layout.plan.text.ayat[ayah - 1],
      _order(ayah).toDouble(),
    );
    return ayah == passage._selectedIndex
        ? Semantics(
            container: true,
            selected: true,
            sortKey: OrdinalSortKey(_order(ayah).toDouble()),
            child: reading,
          )
        : reading;
  }
}

final class _BlockPainter extends CustomPainter {
  const _BlockPainter(
    this.layout,
    this.selected, {
    required this.fill,
    required this.line,
  });

  final BlockLayout layout;
  final int selected;
  final Color fill;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    // `.qk-hl-select`: a background and a thin frame inside it, painted
    // behind the text and never changing it.
    for (final box in layout.ayahBoxes(selected)) {
      final shape = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          box.left - _selectionInset,
          box.top,
          box.right + _selectionInset,
          box.bottom,
        ),
        const Radius.circular(AppRadius.radiusSm),
      );
      canvas
        ..drawRRect(shape, Paint()..color = fill)
        ..drawRRect(
          shape.deflate(_selectionRing / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _selectionRing
            ..color = line,
        );
    }
    layout.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(_BlockPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.selected != selected ||
      oldDelegate.fill != fill ||
      oldDelegate.line != line;
}
