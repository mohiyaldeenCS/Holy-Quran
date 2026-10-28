import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/reader_screen_metrics.dart';
import 'package:holyquran/ui/core/widgets/bookmark_ribbon.dart';

import 'block_layout.dart';
import 'margin_mark.dart';
import 'reader_block.dart';
import 'ribbon_category.dart';

/// What a block's margin shows beside its lines (`RD-02`, `RD-15`, `UD-05`),
/// drawn over the margin's edge and not in the text column (D-140, 1): each
/// margin mark of [BlockLayout.marginMarks] at the start side, level with its
/// line, and a [BookmarkRibbon] at the end side beside the first line of
/// each bookmarked ayah that begins in the block.
///
/// It takes no part in taps. A screen reader reads a mark before the ayah it
/// belongs to, and a ribbon after it.
final class BlockMargin extends StatelessWidget {
  const BlockMargin({
    required this.layout,
    this.bookmarks = const {},
    super.key,
  });

  final BlockLayout layout;

  /// The category of each bookmarked ayah, by address.
  final Map<QuranAddress, BuiltinCategory> bookmarks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = layout.plan.text;
    final firstLine = layout.block.firstLine;
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (mark, band) in layout.marginMarks)
            PositionedDirectional(
              start: -ReaderScreenMetrics.marginMarkOutset,
              top: band.top,
              height: band.height,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  container: true,
                  sortKey: OrdinalSortKey(readingOrder(mark.ayah) - 2),
                  child: MarginMarkView(mark),
                ),
              ),
            ),
          for (final MapEntry(key: address, value: category)
              in bookmarks.entries)
            if (address.riwaya == text.riwaya &&
                address.surah == text.surah &&
                _beginsHere(address.ayah, firstLine))
              PositionedDirectional(
                end: -ReaderScreenMetrics.ribbonOutset,
                top:
                    layout.topOfAyah(address.ayah)! +
                    (layout.plan.lineHeight - BookmarkRibbon.size.height) / 2,
                child: Semantics(
                  container: true,
                  sortKey: OrdinalSortKey(readingOrder(address.ayah) + 2),
                  child: BookmarkRibbon(
                    shape: ribbonShapeOf(category),
                    label: l10n.ayahRowBookmark,
                    category: ribbonCategoryName(l10n, category),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  bool _beginsHere(int ayah, int firstLine) {
    if (ayah < 1 || ayah > layout.plan.text.ayat.length) return false;
    if (layout.topOfAyah(ayah) == null) return false;
    final line = layout.plan.lineOfAyahText(ayah) - firstLine;
    return line >= 0 && line < layout.lineCount;
  }
}
