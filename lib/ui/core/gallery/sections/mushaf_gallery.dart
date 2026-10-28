import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_samples.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/reader/reader_highlights.dart';
import 'package:holyquran/ui/core/reader/reader_style.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/reader/surah_text.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';
import 'package:holyquran/ui/core/widgets/bookmark_ribbon.dart';
import 'package:holyquran/ui/core/widgets/surah_list_item.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';

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

// The highlight states of «التمييز داخل النص» (`Mushaf.dc.html`) are shown on
// a one-ayah synthetic surah of the sample text: the second word is the one
// spoken, matched or left plain.
const String _riwaya = 'sample';
const int _surah = 1;
const int _ayah = 1;
const int _word = 2;

/// The gallery's mushaf section: `AyahRow` and `SurahListItem` in their
/// states, and the reader's highlights, on synthetic text.
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
        GallerySection(
          title: l10n.gallerySectionQuranText,
          child: _Highlights(l10n),
        ),
      ],
    );
  }
}

final class _Highlights extends StatelessWidget {
  const _Highlights(this.l10n);

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final address = QuranAddress(_riwaya, _surah, _ayah);
    final word = QuranAddress(_riwaya, _surah, _ayah, _word);
    final text = GallerySamples.surah(l10n, riwaya: _riwaya, number: _surah);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space3,
      children: [
        for (final highlights in [
          ReaderHighlights(recitedAyah: address, spokenWord: word),
          ReaderHighlights(selectedAyah: address),
          ReaderHighlights(searchMatches: {word}),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
            child: LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: _heightOf(context, text, constraints.maxWidth),
                child: CustomScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  slivers: [
                    InteractiveSurahSliver(text: text, highlights: highlights),
                  ],
                ),
              ),
            ),
          ),
        const Center(
          child: AyahToolbar(
            onPlay: _none,
            onBookmark: _none,
            onStudy: _none,
            onCopy: _none,
            onShare: _none,
          ),
        ),
        const Center(
          child: AyahToolbar(
            onPlay: _none,
            onBookmark: _none,
            bookmarked: true,
            onUndo: _none,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: AppSpacing.space4,
          children: [
            for (final (shape, name) in [
              (TagShape.circle, l10n.tagMemorise),
              (TagShape.square, l10n.tagReview),
              (TagShape.diamond, l10n.tagStudy),
              (TagShape.ring, l10n.tagImportant),
            ])
              BookmarkRibbon(
                shape: shape,
                label: l10n.ayahRowBookmark,
                category: name,
              ),
          ],
        ),
      ],
    );
  }
}

// The sliver needs a bounded viewport: the height its text takes at [width].
double _heightOf(BuildContext context, SurahText text, double width) =>
    SurahLayout.plan(
      text,
      ReaderStyle(ReaderTextScaler(MediaQuery.textScalerOf(context), 1)),
      width,
    ).height;

void _none() {}
