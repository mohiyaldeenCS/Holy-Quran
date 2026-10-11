import 'package:flutter/widgets.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import 'spike_surah_text.dart';
import 'surah_list_v1.dart';
import 'surah_paragraph.dart';
import 'surah_text_block.dart';

/// One block of V2: where its paragraph starts, which ayat it lays out,
/// how many of its first lines are a hidden lead-in and how many it shows.
typedef FlowBlock = ({
  int firstIndex,
  int lastIndex,
  int startOffset,
  bool markAtStart,
  int leadIn,
  int? maxLines,
});

/// Cuts a surah into blocks, one per reference page, that break their
/// lines exactly as one block of the whole surah would (V1), so that the
/// text keeps flowing across page marks (D-071).
///
/// Line breaking is first fit, so a line depends only on where it starts
/// and on how its words are shaped. Each block shows the lines from V1's
/// line holding its page mark, possibly inside an ayah at a stored word
/// offset, or at a marker or page mark. Its paragraph starts one V1 line
/// earlier, a hidden lead-in, so that the first shown words are shaped
/// after the words before them: Amiri Quran shapes a word differently on
/// its own (a word-initial kaf is 0.24 em wider). The lead-in must break as
/// V1 does, which planning checks, going back up to [_maxLeadIn] lines. A
/// block lays out through the next page's first ayah and shows only the
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
       ],
       _starts = [(ayah: surah.firstAyah.ayah, offset: 0)];

  final SpikeSurahText surah;
  final double width;
  final TextScaler textScaler;

  /// The size every page mark is held to; null for no page marks, when the
  /// blocks still follow the page ranges.
  final Size? pageMarkSize;

  /// The indices of the ayat at which a reference page starts.
  final List<int> _pages;

  /// V1's line starts as far as planned; the last is the next block's first
  /// shown line.
  final List<LineStart> _starts;
  final _blocks = <FlowBlock>[];
  var _done = false;

  /// Blocks whose lead-in would not break as V1 does, which start without
  /// one; their first words may be shaped unlike V1's.
  int get blocksWithoutLeadIn => _withoutLeadIn;
  var _withoutLeadIn = 0;

  /// Block [k], planning up to it; null past the last block.
  FlowBlock? block(int k) {
    while (_blocks.length <= k && !_done) {
      _planNext();
    }
    return k < _blocks.length ? _blocks[k] : null;
  }

  /// Plans every block.
  List<FlowBlock> get all {
    while (!_done) {
      _planNext();
    }
    return List.unmodifiable(_blocks);
  }

  void _planNext() {
    final shown = _starts.length - 1;
    final backs = shown == 0
        ? const [0]
        : [
            for (var back = 1; back <= _maxLeadIn && back <= shown; back++)
              back,
          ];
    for (final back in [...backs, 0]) {
      if (_plan(shown, back)) return;
    }
    throw StateError('block from line $shown could not be planned');
  }

  /// Plans the block whose first shown line is V1's line [shown], with
  /// [back] lines of lead-in; false when the lead-in breaks unlike V1.
  bool _plan(int shown, int back) {
    final origin = _starts[shown - back];
    final first = _starts[shown].ayah - surah.firstAyah.ayah;
    FlowBlock blockTo(int last, int? maxLines) => (
      firstIndex: origin.ayah - surah.firstAyah.ayah,
      lastIndex: last,
      startOffset: origin.offset < 0 ? 0 : origin.offset,
      markAtStart: origin.offset < 0,
      leadIn: back,
      maxLines: maxLines,
    );
    bool leadInHolds(List<LineStart> positions) {
      if (positions.length <= back) return false;
      for (var k = 0; k <= back; k++) {
        if (positions[k] != _starts[shown - back + k]) return false;
      }
      return true;
    }

    for (final page in _pages) {
      if (page <= first) continue;
      final block = blockTo(page, null);
      final paragraph = paragraphFor(block, planning: true);
      final positions = paragraph.lineStartPositions;
      final line = paragraph.lineOfAyah(page - block.firstIndex);
      paragraph.dispose();
      if (!leadInHolds(positions)) return false;
      if (line <= back) continue;
      _blocks.add(blockTo(page, line - back));
      _starts.addAll(positions.sublist(back + 1, line + 1));
      if (back == 0 && shown > 0) _withoutLeadIn++;
      return true;
    }
    final block = blockTo(surah.ayat.length - 1, null);
    final paragraph = paragraphFor(block, planning: true);
    final positions = paragraph.lineStartPositions;
    paragraph.dispose();
    if (!leadInHolds(positions)) return false;
    _blocks.add(block);
    if (back == 0 && shown > 0) _withoutLeadIn++;
    _done = true;
    return true;
  }

  /// What [block] lays out, with the sizes the marks will take.
  SurahBlockContent contentOf(FlowBlock block) => SurahBlockContent(
    firstAyah: _ayahOf(surah, block.firstIndex),
    ayat: surah.ayat.sublist(block.firstIndex, block.lastIndex + 1),
    words: surah.words.sublist(block.firstIndex, block.lastIndex + 1),
    marks: surah.marks.sublist(block.firstIndex, block.lastIndex + 1),
    basmala:
        block.firstIndex == 0 && block.startOffset == 0 && block.leadIn == 0
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
      leadInLines: planning ? 0 : block.leadIn,
    )..layout(width);
  }
}

// Lead-in lines tried before a block starts without one.
const int _maxLeadIn = 3;

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
              marks: content.marks,
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
              leadInLines: block.leadIn,
            );
          },
        );
      },
    );
  }
}
