import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_samples.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/continue_listening_row.dart';
import 'package:holyquran/ui/core/widgets/home_door.dart';
import 'package:holyquran/ui/core/widgets/home_header.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';
import 'package:holyquran/ui/core/widgets/splash.dart';

// Screens.dc.html, home doors: `grid-template-columns:repeat(4, ...)`, gap
// 8px (space-2); the two Phase 1 doors take the first two columns (D-089, 9).
const int _doorColumns = 4;

// Screens.dc.html, «أكمل الاستماع» row: «سورة الكهف · الآية ١٠», the ayah.
const int _listeningAyah = 10;

// Share.dc.html, the three cards: the ayah at 34, 26 and 23px, and the
// reference ayah 5, 152 and 28.
const _shareCards = [
  (design: ShareCardDesign.emerald, fontSize: 34.0, ayah: 5),
  (design: ShareCardDesign.paper, fontSize: 26.0, ayah: 152),
  (design: ShareCardDesign.night, fontSize: 23.0, ayah: 28),
];

// Share.dc.html, splash: the phone frame is `width:300px;height:650px`.
const Size _splashFrame = Size(300, 650);

/// The gallery's home and share section: the home board's header, doors and
/// «أكمل الاستماع» row, the three share cards and the splash, on synthetic
/// text.
class HomeShareGallery extends StatelessWidget {
  const HomeShareGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final doors = [
      HomeDoor(
        icon: IconName.indexIcon,
        label: l10n.homeDoorIndex,
        onPressed: _none,
      ),
      HomeDoor(
        icon: IconName.bookmark,
        label: l10n.homeDoorBookmarks,
        onPressed: _none,
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space6,
      children: [
        GallerySection(
          title: l10n.gallerySectionHomeHeader,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.space3,
            children: [
              HomeHeader(onSearch: _none),
              HomeHeader(),
            ],
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionHomeDoor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.space2,
            children: [
              for (var column = 0; column < _doorColumns; column++)
                Expanded(
                  child: column < doors.length
                      ? doors[column]
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionContinueListeningRow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.space3,
            children: [
              ContinueListeningRow(
                surahName: GallerySamples.surahName(l10n),
                ayah: _listeningAyah,
                reciter: l10n.sampleReciter,
                onPlay: _none,
              ),
              ContinueListeningRow(
                surahName: GallerySamples.surahName(l10n),
                ayah: _listeningAyah,
                onPlay: _none,
              ),
            ],
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionShareCard,
          child: galleryRow([
            for (final (:design, :fontSize, :ayah) in _shareCards)
              ShareCard(
                ayah: GallerySamples.text(l10n),
                surahName: GallerySamples.surahName(l10n),
                ayahNumber: ayah,
                ayahFontSize: fontSize,
                design: design,
              ),
          ]),
        ),
        GallerySection(
          title: l10n.gallerySectionSplash,
          child: Center(
            child: SizedBox.fromSize(size: _splashFrame, child: const Splash()),
          ),
        ),
      ],
    );
  }
}

void _none() {}
