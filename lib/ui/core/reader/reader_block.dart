import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import 'block_layout.dart';
import 'page_mark.dart';
import 'reader_paragraph.dart';

/// One laid-out block of surah-mode text: its paragraphs, each ayah's
/// `AyahMarker` in its slot and each page mark in its own. Markers and page
/// marks follow the block's text scale, so they fill the slots the text left
/// for them. A screen reader reads each page mark, then the ayah's text,
/// then its marker (`AX-01`).
final class ReaderBlock extends StatelessWidget {
  const ReaderBlock(this.layout, {super.key});

  final BlockLayout layout;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: layout.plan.style.scaler),
    child: SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _BlockPainter(layout))),
          for (final MapEntry(key: ayah, value: page)
              in layout.pageMarks.entries)
            Positioned.fromRect(
              rect: layout.pageMarkRect(ayah)!,
              child: Semantics(
                container: true,
                sortKey: OrdinalSortKey(_order(ayah) - 1),
                child: PageMark(page: page),
              ),
            ),
          for (final ayah in layout.ayat) ...[
            Positioned.fromRect(
              rect: layout.ayahRect(ayah)!,
              child: ayahSemantics(
                layout.plan.text.ayat[ayah - 1],
                _order(ayah).toDouble(),
              ),
            ),
            Positioned.fromRect(
              rect: layout.markerRect(ayah)!,
              child: Semantics(
                container: true,
                sortKey: OrdinalSortKey(_order(ayah) + 1),
                child: AyahMarker(number: ayah),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

int _order(int ayah) => 3 * ayah;

final class _BlockPainter extends CustomPainter {
  const _BlockPainter(this.layout);

  final BlockLayout layout;

  @override
  void paint(Canvas canvas, Size size) => layout.paint(canvas, Offset.zero);

  @override
  bool shouldRepaint(_BlockPainter oldDelegate) => oldDelegate.layout != layout;
}
