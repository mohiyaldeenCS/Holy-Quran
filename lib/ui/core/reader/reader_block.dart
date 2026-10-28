import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import 'block_layout.dart';
import 'page_mark.dart';
import 'reader_paragraph.dart';

/// One laid-out block of surah-mode text: its paragraphs, each ayah's
/// `AyahMarker` in its slot and each page mark in its own. Markers and page
/// marks follow the block's text scale, so they fill the slots the text left
/// for them. A screen reader reads each page mark, then the ayah's text,
/// then its marker (`AX-01`).
///
/// The marker of [selectedAyah] takes the selected state. With
/// [onAyahActivated] a screen reader can activate an ayah's text and its
/// marker, which stand for the long press and the tap on the marker that it
/// cannot make (D-141, 7); the callback gets the ayah number.
final class ReaderBlock extends StatelessWidget {
  const ReaderBlock(
    this.layout, {
    this.selectedAyah,
    this.onAyahActivated,
    super.key,
  });

  final BlockLayout layout;
  final int? selectedAyah;
  final ValueChanged<int>? onAyahActivated;

  @override
  Widget build(BuildContext context) {
    final activate = onAyahActivated;
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
            Positioned.fill(child: CustomPaint(painter: _BlockPainter(layout))),
            for (final MapEntry(key: ayah, value: page)
                in layout.pageMarks.entries)
              Positioned.fromRect(
                rect: layout.pageMarkRect(ayah)!,
                child: Semantics(
                  container: true,
                  sortKey: OrdinalSortKey(readingOrder(ayah) - 1),
                  child: PageMark(page: page),
                ),
              ),
            for (final ayah in layout.ayat) ...[
              Positioned.fromRect(
                rect: layout.ayahRect(ayah)!,
                child: ayahSemantics(
                  layout.plan.text.ayat[ayah - 1],
                  readingOrder(ayah).toDouble(),
                  selected: ayah == selectedAyah,
                  onActivate: activate == null ? null : () => activate(ayah),
                ),
              ),
              Positioned.fromRect(
                rect: layout.markerRect(ayah)!,
                child: _marker(context, ayah, activate),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _marker(BuildContext context, int ayah, ValueChanged<int>? activate) {
    final marker = AyahMarker(number: ayah, selected: ayah == selectedAyah);
    final sortKey = OrdinalSortKey(readingOrder(ayah) + 1);
    if (activate == null) {
      return Semantics(container: true, sortKey: sortKey, child: marker);
    }
    // The marker names itself (AyahMarker); naming it here too puts its
    // action on the node a screen reader lands on.
    return Semantics(
      container: true,
      sortKey: sortKey,
      button: true,
      selected: ayah == selectedAyah,
      label: AppLocalizations.of(context).ayahMarkerLabel(arabicDigits(ayah)),
      onTap: () => activate(ayah),
      child: ExcludeSemantics(child: marker),
    );
  }
}

/// Where the semantics of [ayah] stand among a block's: a page mark one
/// before the ayah's text, its marker one after, a margin mark two before and
/// a bookmark ribbon two after.
int readingOrder(int ayah) => 5 * ayah;

final class _BlockPainter extends CustomPainter {
  const _BlockPainter(this.layout);

  final BlockLayout layout;

  @override
  void paint(Canvas canvas, Size size) => layout.paint(canvas, Offset.zero);

  @override
  bool shouldRepaint(_BlockPainter oldDelegate) => oldDelegate.layout != layout;
}
