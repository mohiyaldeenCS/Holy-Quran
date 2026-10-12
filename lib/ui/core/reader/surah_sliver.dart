import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

import 'block_layout.dart';
import 'reader_block.dart';
import 'reader_style.dart';
import 'reader_text_scale.dart';
import 'surah_layout.dart';
import 'surah_text.dart';

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
    super.key,
  });

  final SurahText text;
  final double step;
  final ValueChanged<SurahLayout>? onLayout;

  @override
  State<SurahSliver> createState() => _SurahSliverState();
}

final class _SurahSliverState extends State<SurahSliver> {
  ReaderStyle? _style;
  SurahLayout? _layout;
  Widget? _list;

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

/// Lays a block out while it is built, in the theme's `quran-ink`, and
/// frees its paragraphs when it goes.
final class _BlockHost extends StatefulWidget {
  const _BlockHost({required this.layout, required this.index, super.key});

  final SurahLayout layout;
  final int index;

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
      ReaderBlock(_blockIn(context.colors.quranInk));
}
