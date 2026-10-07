import 'package:flutter/widgets.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import 'spike_surah_text.dart';
import 'surah_list_v1.dart';
import 'surah_paragraph.dart';
import 'surah_text_block.dart';

/// One block of V2: where it starts, which ayat it lays out and how many of
/// its lines it shows.
typedef FlowBlock = ({
  int firstIndex,
  int lastIndex,
  int startOffset,
  bool markAtStart,
  int? maxLines,
});

/// Cuts a surah into blocks, one per reference page, that break their
/// lines exactly as one block of the whole surah would (V1), so that the
/// text keeps flowing across page marks (D-071).
///
/// Line breaking is first fit, so a line depends only on where it starts.
/// Each block therefore starts where V1's line holding its page mark starts,
/// possibly inside an ayah at a stored word offset, or at a marker or page
/// mark. It lays out through the next page's first ayah and shows only the
/// lines before the one holding the next page mark, so its last shown line
/// is not the paragraph's last and stays justified. A page whose mark falls
/// on the block's first line joins the next block.
///
/// Planning lays out each block once more than painting it does; it runs
/// in order, as far as the list has asked.
final class SurahFlowPlanner {
  SurahFlowPlanner({
    required this.surah,
    required this.width,
    required this.textScaler,
    this.pageMarkSize,
  }) : _pages = [
         for (var i = 0; i < surah.ayat.length; i++)
           if (surah.pageStarts.containsKey(_ayahOf(surah, i))) i,
       ];

  final SpikeSurahText surah;
  final double width;
  final TextScaler textScaler;

  /// The size every page mark is held to; null for no page marks, when the
  /// blocks still follow the page ranges.
  final Size? pageMarkSize;

  /// The indices of the ayat at which a reference page starts.
  final List<int> _pages;
  final _blocks = <FlowBlock>[];
  ({int index, int offset, bool mark})? _next = (
    index: 0,
    offset: 0,
    mark: false,
  );

  /// Block [k], planning up to it; null past the last block.
  FlowBlock? block(int k) {
    while (_blocks.length <= k && _next != null) {
      _planNext();
    }
    return k < _blocks.length ? _blocks[k] : null;
  }

  /// Plans every block.
  List<FlowBlock> get all {
    while (_next != null) {
      _planNext();
    }
    return List.unmodifiable(_blocks);
  }

  void _planNext() {
    final start = _next!;
    for (final page in _pages) {
      if (page <= start.index) continue;
      final block = (
        firstIndex: start.index,
        lastIndex: page,
        startOffset: start.offset,
        markAtStart: start.mark,
        maxLines: null,
      );
      final paragraph = paragraphFor(block, planning: true);
      final line = paragraph.lineOfAyah(page - start.index);
      final next = line >= 1 ? paragraph.lineStartPositions[line] : null;
      paragraph.dispose();
      if (next == null) continue;
      _blocks.add((
        firstIndex: block.firstIndex,
        lastIndex: block.lastIndex,
        startOffset: block.startOffset,
        markAtStart: block.markAtStart,
        maxLines: line,
      ));
      _next = (
        index: next.ayah - surah.firstAyah.ayah,
        offset: next.offset < 0 ? 0 : next.offset,
        mark: next.offset < 0,
      );
      return;
    }
    _blocks.add((
      firstIndex: start.index,
      lastIndex: surah.ayat.length - 1,
      startOffset: start.offset,
      markAtStart: start.mark,
      maxLines: null,
    ));
    _next = null;
  }

  /// What [block] lays out, with the sizes the marks will take.
  SurahBlockContent contentOf(FlowBlock block) => SurahBlockContent(
    firstAyah: _ayahOf(surah, block.firstIndex),
    ayat: surah.ayat.sublist(block.firstIndex, block.lastIndex + 1),
    words: surah.words.sublist(block.firstIndex, block.lastIndex + 1),
    basmala: block.firstIndex == 0 && block.startOffset == 0
        ? surah.basmala
        : null,
    startOffset: block.startOffset,
    pageMarks: {
      if (pageMarkSize != null)
        for (final i in _pages)
          if ((i > block.firstIndex ||
                  (i == block.firstIndex && block.markAtStart)) &&
              i <= block.lastIndex)
            _ayahOf(surah, i),
    },
  );

  /// [block] laid out as its [SurahTextBlock] will be or, when only
  /// [planning], with every line shown and none moved.
  SurahParagraph paragraphFor(FlowBlock block, {bool planning = false}) {
    final content = contentOf(block);
    return SurahParagraph(
      content,
      style: _layoutStyle,
      textScaler: textScaler,
      markerSizes: List.filled(
        content.length,
        ayahMarkerSize(textScaler, AppSizes.ayahMarker),
      ),
      pageMarkSizes: List.filled(
        content.pageMarks.length,
        pageMarkSize ?? Size.zero,
      ),
      centreLastLine: !planning && block.maxLines == null,
      maxLines: planning ? null : block.maxLines,
    )..layout(width);
  }
}

// Colour does not change layout; any token will do for planning.
final TextStyle _layoutStyle = AppTextStyles.quranPage.copyWith(
  color: AppColors.paper.quranInk,
);

QuranAddress _ayahOf(SpikeSurahText surah, int index) => QuranAddress(
  surah.firstAyah.riwaya,
  surah.firstAyah.surah,
  surah.firstAyah.ayah + index,
);

/// V2: the surah as blocks per reference page in a lazily built list, cut by
/// a [SurahFlowPlanner] for the list's width and text scale.
final class PageBlocksV2 extends StatefulWidget {
  const PageBlocksV2({
    required this.surah,
    this.highlighted = const {},
    this.onWordTap,
    this.pageMark,
    this.pageMarkSize = Size.zero,
    this.controller,
    this.blockKey,
    super.key,
  });

  final SpikeSurahText surah;
  final Set<QuranAddress> highlighted;
  final ValueChanged<QuranAddress>? onWordTap;
  final PageMarkBuilder? pageMark;
  final Size pageMarkSize;
  final ScrollController? controller;

  /// Keys block [k], for tests and measurement.
  final Key Function(int k)? blockKey;

  @override
  State<PageBlocksV2> createState() => _PageBlocksV2State();
}

final class _PageBlocksV2State extends State<PageBlocksV2> {
  SurahFlowPlanner? _planner;

  Size? get _pageMarkSize =>
      widget.pageMark == null ? null : widget.pageMarkSize;

  SurahFlowPlanner _plannerFor(double width, TextScaler scaler) {
    final planner = _planner;
    if (planner != null &&
        planner.width == width &&
        planner.textScaler == scaler &&
        planner.pageMarkSize == _pageMarkSize &&
        identical(planner.surah, widget.surah)) {
      return planner;
    }
    return _planner = SurahFlowPlanner(
      surah: widget.surah,
      width: width,
      textScaler: scaler,
      pageMarkSize: _pageMarkSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final marks = pageMarksOf(
      context,
      widget.surah,
      widget.pageMark,
      widget.pageMarkSize,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final planner = _plannerFor(constraints.maxWidth, scaler);
        return ListView.builder(
          controller: widget.controller,
          itemBuilder: (context, k) {
            final block = planner.block(k);
            if (block == null) return null;
            final content = planner.contentOf(block);
            return SurahTextBlock(
              key: widget.blockKey?.call(k),
              firstAyah: content.firstAyah,
              ayat: content.ayat,
              words: content.words,
              basmala: content.basmala,
              startOffset: content.startOffset,
              markers: [
                for (var i = 0; i < content.length; i++)
                  AyahMarker(
                    number: content.ayahAt(i).ayah,
                    playing: widget.highlighted.contains(content.ayahAt(i)),
                  ),
              ],
              pageMarks: {
                for (final ayah in content.pageMarks) ayah: marks[ayah]!,
              },
              highlighted: widget.highlighted,
              onWordTap: widget.onWordTap,
              centreLastLine: block.maxLines == null,
              maxLines: block.maxLines,
            );
          },
        );
      },
    );
  }
}
