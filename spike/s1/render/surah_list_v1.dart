import 'package:flutter/widgets.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import 'spike_surah_text.dart';
import 'surah_text_block.dart';

/// The page mark of RD-06 for reference page [page]. Its look is not in the
/// identity yet (D-071); the spike takes it from the caller and holds it to
/// a fixed size so that V1 and V2 lay out alike.
typedef PageMarkBuilder = Widget Function(BuildContext context, int page);

/// Wraps each text block a list builds, such as in a `BlockGestures`; the
/// wrapper must keep the block's place and size.
typedef BlockWrapper =
    Widget Function(BuildContext context, SurahTextBlock block);

/// V1: the whole surah as one [SurahTextBlock] in a scroll view. Layout
/// is one paragraph of the whole surah; the viewport clips its painting.
final class SurahListV1 extends StatelessWidget {
  const SurahListV1({
    required this.surah,
    this.highlighted = const {},
    this.selected = const {},
    this.wrapBlock,
    this.pageMark,
    this.pageMarkSize = Size.zero,
    this.controller,
    this.blockKey,
    super.key,
  });

  final SpikeSurahText surah;
  final Set<QuranAddress> highlighted;
  final Set<QuranAddress> selected;
  final BlockWrapper? wrapBlock;
  final PageMarkBuilder? pageMark;
  final Size pageMarkSize;
  final ScrollController? controller;
  final Key? blockKey;

  @override
  Widget build(BuildContext context) {
    final block = SurahTextBlock(
      key: blockKey,
      firstAyah: surah.firstAyah,
      ayat: surah.ayat,
      words: surah.words,
      marks: surah.marks,
      basmala: surah.basmala,
      markers: [
        for (var i = 0; i < surah.ayat.length; i++)
          AyahMarker(
            number: surah.firstAyah.ayah + i,
            playing: highlighted.contains(_ayah(i)),
          ),
      ],
      pageMarks: pageMarksOf(context, surah, pageMark, pageMarkSize),
      highlighted: highlighted,
      selected: selected,
    );
    return SingleChildScrollView(
      controller: controller,
      child: wrapBlock?.call(context, block) ?? block,
    );
  }

  QuranAddress _ayah(int index) => QuranAddress(
    surah.firstAyah.riwaya,
    surah.firstAyah.surah,
    surah.firstAyah.ayah + index,
  );
}

/// The page marks of [surah] built by [builder], each held to [size].
Map<QuranAddress, Widget> pageMarksOf(
  BuildContext context,
  SpikeSurahText surah,
  PageMarkBuilder? builder,
  Size size,
) => builder == null
    ? const {}
    : {
        for (final MapEntry(key: ayah, value: page) in surah.pageStarts.entries)
          ayah: SizedBox.fromSize(size: size, child: builder(context, page)),
      };
