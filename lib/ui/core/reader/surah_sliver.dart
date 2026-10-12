import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

import 'block_layout.dart';
import 'reader_block.dart';
import 'reader_style.dart';
import 'reader_text_scale.dart';
import 'surah_layout.dart';
import 'surah_text.dart';

/// Builds what a block shows from its layout; [ReaderBlock] by default.
typedef ReaderBlockBuilder =
    Widget Function(BuildContext context, BlockLayout layout);

/// A surah in surah mode as a sliver (`RD-02`): the basmala on its own
/// centred line when the surah shows one, then the text in blocks, each laid
/// out only when it comes near the screen. Every extent is known from the
/// plan, so [SurahLayout.offsetOf] and [SurahLayout.ayahAt] hold before any
/// block is laid out.
///
/// The text is set at reader step [step] on top of the system text scale
/// (`RD-07`). [onLayout] hears each new plan, after the frame that made it.
final class SurahSliver extends StatefulWidget {
  const SurahSliver({
    required this.text,
    this.step = 1,
    this.onLayout,
    this.blockBuilder = _readerBlock,
    super.key,
  });

  final SurahText text;
  final double step;
  final ValueChanged<SurahLayout>? onLayout;
  final ReaderBlockBuilder blockBuilder;

  static Widget _readerBlock(BuildContext context, BlockLayout layout) =>
      ReaderBlock(layout);

  @override
  State<SurahSliver> createState() => _SurahSliverState();
}

final class _SurahSliverState extends State<SurahSliver> {
  SurahLayout? _layout;

  SurahLayout _layoutFor(double width, ReaderStyle style) {
    final last = _layout;
    if (last != null &&
        identical(last.text, widget.text) &&
        last.style == style &&
        last.width == width) {
      return last;
    }
    final layout = SurahLayout.plan(widget.text, style, width);
    _layout = layout;
    if (widget.onLayout case final onLayout?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_layout, layout)) onLayout(layout);
      });
    }
    return layout;
  }

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final scaler = ReaderTextScaler(
        MediaQuery.textScalerOf(context),
        widget.step,
      );
      final layout = _layoutFor(
        constraints.crossAxisExtent,
        ReaderStyle(scaler),
      );
      final basmala = widget.text.showsBasmala ? 1 : 0;
      return SliverVariedExtentList.builder(
        itemCount: basmala + layout.blocks.length,
        itemExtentBuilder: (index, _) {
          if (index < basmala) return layout.basmalaExtent;
          final block = index - basmala;
          return block < layout.blocks.length
              ? layout.blockHeight(block)
              : null;
        },
        itemBuilder: (context, index) {
          if (index < basmala) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: Align(
                alignment: Alignment.topCenter,
                child: QuranText(
                  widget.text.basmala!,
                  align: QuranTextAlign.center,
                ),
              ),
            );
          }
          return _BlockHost(
            key: ValueKey((layout, index - basmala)),
            layout: layout,
            index: index - basmala,
            builder: widget.blockBuilder,
          );
        },
      );
    },
  );
}

/// Lays a block out while it is built, in the theme's `quran-ink`, and
/// frees its paragraphs when it goes.
final class _BlockHost extends StatefulWidget {
  const _BlockHost({
    required this.layout,
    required this.index,
    required this.builder,
    super.key,
  });

  final SurahLayout layout;
  final int index;
  final ReaderBlockBuilder builder;

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
      widget.builder(context, _blockIn(context.colors.quranInk));
}
