import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

import 'block_highlights.dart';
import 'block_layout.dart';
import 'gesture_target.dart';
import 'reader_block.dart';
import 'reader_highlights.dart';
import 'reader_style.dart';
import 'reader_text_scale.dart';
import 'surah_layout.dart';
import 'surah_text.dart';
import 'tap_resolver.dart';
import 'target_gestures.dart';

/// Draws what sits over a block, in the block's coordinates: its size is the
/// block's, its [BlockLayout] says where lines, ayat and margin marks are.
typedef BlockOverlayBuilder =
    Widget Function(BuildContext context, BlockLayout layout);

/// A surah in surah mode as [SurahSliver] draws it, with the reader's
/// gestures: one gesture layer per block resolves a tap or long press to a
/// [GestureTarget] by `resolveTap`, and the basmala gives the margin
/// (`RD-02`, PRD §7.4).
///
/// [blockOverlayBuilder], when given, adds a layer above each block's text
/// that does not take part in tap resolution; it is where the screen draws
/// the block's margin marks from [BlockLayout.marginMarks]. It is called when
/// a block is built, not on every rebuild of the sliver, and the callbacks
/// are read when a gesture ends, so a new closure changes nothing.
final class InteractiveSurahSliver extends StatefulWidget {
  const InteractiveSurahSliver({
    required this.text,
    this.step = 1,
    this.onLayout,
    this.highlights = ReaderHighlights.none,
    this.onTap,
    this.onLongPress,
    this.blockOverlayBuilder,
    super.key,
  });

  final SurahText text;
  final double step;
  final ValueChanged<SurahLayout>? onLayout;

  /// Painted behind the glyphs, and the recited ayah's marker filled; the
  /// text itself is never changed (`docs/DESIGN_SYSTEM.md`).
  final ReaderHighlights highlights;
  final ValueChanged<GestureTarget>? onTap;
  final ValueChanged<GestureTarget>? onLongPress;
  final BlockOverlayBuilder? blockOverlayBuilder;

  @override
  State<InteractiveSurahSliver> createState() => _InteractiveSurahSliverState();
}

final class _InteractiveSurahSliverState extends State<InteractiveSurahSliver> {
  ReaderStyle? _style;
  SurahLayout? _layout;
  Widget? _list;

  @override
  void didUpdateWidget(InteractiveSurahSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlights != widget.highlights ||
        (oldWidget.onTap == null) != (widget.onTap == null) ||
        (oldWidget.onLongPress == null) != (widget.onLongPress == null) ||
        (oldWidget.blockOverlayBuilder == null) !=
            (widget.blockOverlayBuilder == null)) {
      _list = null;
    }
  }

  void _tap(GestureTarget target) => widget.onTap?.call(target);

  void _longPress(GestureTarget target) => widget.onLongPress?.call(target);

  Widget _overlay(BuildContext context, BlockLayout layout) =>
      widget.blockOverlayBuilder!(context, layout);

  // SliverLayoutBuilder builds again on every scroll offset; returning the
  // same list while the plan holds lets Flutter skip the blocks.
  Widget _listFor(double width, TextScaler scaler) {
    final style = _style?.scaler == scaler
        ? _style!
        : _style = ReaderStyle(scaler);
    final last = _layout;
    if (last != null &&
        identical(last.text, widget.text) &&
        last.style == style &&
        last.width == width) {
      return _list ??= _buildList(last, scaler);
    }
    final layout = _layout = SurahLayout.plan(widget.text, style, width);
    if (widget.onLayout case final onLayout?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_layout, layout)) onLayout(layout);
      });
    }
    return _list = _buildList(layout, scaler);
  }

  Widget _buildList(SurahLayout layout, TextScaler scaler) {
    final basmala = widget.text.showsBasmala ? 1 : 0;
    return SliverVariedExtentList.builder(
      itemCount: basmala + layout.blocks.length,
      itemExtentBuilder: (index, _) {
        if (index < basmala) return layout.basmalaExtent;
        final block = index - basmala;
        return block < layout.blocks.length ? layout.blockHeight(block) : null;
      },
      itemBuilder: (context, index) {
        if (index < basmala) {
          return TargetGestures(
            targetAt: (_) => const MarginTarget(),
            onTap: widget.onTap == null ? null : _tap,
            onLongPress: widget.onLongPress == null ? null : _longPress,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: Align(
                alignment: Alignment.topCenter,
                child: QuranText(
                  widget.text.basmala!,
                  align: QuranTextAlign.center,
                ),
              ),
            ),
          );
        }
        return _BlockHost(
          key: ValueKey((layout, index - basmala)),
          layout: layout,
          index: index - basmala,
          highlights: widget.highlights,
          onTap: widget.onTap == null ? null : _tap,
          onLongPress: widget.onLongPress == null ? null : _longPress,
          overlayBuilder: widget.blockOverlayBuilder == null ? null : _overlay,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.textScalerOf(context);
    return SliverLayoutBuilder(
      builder: (context, constraints) => _listFor(
        constraints.crossAxisExtent,
        ReaderTextScaler(system, widget.step),
      ),
    );
  }
}

/// Lays a block out while it is built, in the theme's `quran-ink`, and frees
/// its paragraphs when it goes.
final class _BlockHost extends StatefulWidget {
  const _BlockHost({
    required this.layout,
    required this.index,
    required this.highlights,
    required this.onTap,
    required this.onLongPress,
    required this.overlayBuilder,
    super.key,
  });

  final SurahLayout layout;
  final int index;
  final ReaderHighlights highlights;
  final ValueChanged<GestureTarget>? onTap;
  final ValueChanged<GestureTarget>? onLongPress;
  final BlockOverlayBuilder? overlayBuilder;

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
  Widget build(BuildContext context) {
    final block = _blockIn(context.colors.quranInk);
    return TargetGestures(
      targetAt: (point) => targetInBlock(block, point),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ...highlightsUnder(context, block, widget.highlights),
          ReaderBlock(block),
          ...highlightsOver(context, block, widget.highlights),
          if (widget.overlayBuilder case final overlay?)
            Positioned.fill(child: overlay(context, block)),
        ],
      ),
    );
  }
}
