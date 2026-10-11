import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_samples.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/surah_list_item.dart';

// SurahListItem/preview.html: the three rows shown, by number, place, ayah
// count, start page and last read; the fourth row has neither place nor
// page, as a source that lacks them gives.
const List<
  ({
    int number,
    RevelationPlace? revelation,
    int ayat,
    int? page,
    bool lastRead,
  })
>
_surahs = [
  (
    number: 1,
    revelation: RevelationPlace.makki,
    ayat: 7,
    page: 1,
    lastRead: false,
  ),
  (
    number: 2,
    revelation: RevelationPlace.madani,
    ayat: 286,
    page: 2,
    lastRead: true,
  ),
  (
    number: 3,
    revelation: RevelationPlace.madani,
    ayat: 200,
    page: 50,
    lastRead: false,
  ),
  (number: 114, revelation: null, ayat: 6, page: null, lastRead: false),
];

// AyahRow/preview.html: ayah 5; the second row has a long ayah number.
const int _ayahNumber = 5;
const int _longAyahNumber = 255;

/// The gallery's mushaf section: `AyahRow` and `SurahListItem` in their
/// states, on synthetic text.
class MushafGallery extends StatelessWidget {
  const MushafGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space6,
      children: [
        GallerySection(
          title: l10n.gallerySectionAyahRow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.space3,
            children: [
              AyahRow(
                number: _ayahNumber,
                text: GallerySamples.text(l10n),
                onPlay: _none,
                onBookmark: _none,
                onStudy: _none,
              ),
              AyahRow(
                number: _longAyahNumber,
                text: GallerySamples.longText(l10n),
                onPlay: _none,
              ),
            ],
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionSurahListItem,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (:number, :revelation, :ayat, :page, :lastRead)
                  in _surahs)
                SurahListItem(
                  number: number,
                  name: GallerySamples.surahName(l10n),
                  ayahCount: ayat,
                  revelation: revelation,
                  page: page,
                  lastRead: lastRead,
                  onPressed: _none,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

void _none() {}
