import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_samples.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/continue_card.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/reader_player_bar.dart';
import 'package:holyquran/ui/core/widgets/resource_row.dart';

// ProgressBar/preview.html: `value: 70, height: 8`, then `value: 46` in the
// player tone on a `player` box padded 16 with radius 16.
const double _primaryValue = 0.7;
const double _primaryHeight = 8;
const double _playerValue = 0.46;
// MiniPlayer/preview.html: ayah 5 in the title, `progress: 46, repeat: 3`.
const int _playerAyah = 5;
const int _playerRepeat = 3;
// ContinueCard/preview.html: `progress: 7`.
const double _continueProgress = 0.07;
// ResourceRow/preview.html: `progress: 60` while downloading.
const double _downloadProgress = 0.6;
// Screens.dc.html, the reader's player bar: ayah 4 in the title.
const int _barAyah = 4;

/// The gallery's audio and progress section: `ProgressBar`, `MiniPlayer`,
/// `ContinueCard`, `ResourceRow` and the reader's player bar, as their
/// previews and the Screens board show them, on synthetic text.
class AudioGallery extends StatefulWidget {
  const AudioGallery({super.key});

  @override
  State<AudioGallery> createState() => _AudioGalleryState();
}

class _AudioGalleryState extends State<AudioGallery> {
  bool _playing = true;

  void _togglePlaying() => setState(() => _playing = !_playing);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final surah = GallerySamples.surahName(l10n);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space6,
      children: [
        GallerySection(
          title: l10n.gallerySectionProgressBar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.space4,
            children: [
              ProgressBar(
                value: _primaryValue,
                height: _primaryHeight,
                label: l10n.continueReadingPosition,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.player,
                  borderRadius: BorderRadius.circular(AppRadius.radiusButton),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  child: ProgressBar(
                    value: _playerValue,
                    tone: ProgressBarTone.player,
                    label: l10n.playerPosition,
                  ),
                ),
              ),
            ],
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionMiniPlayer,
          child: MiniPlayer(
            surah: surah,
            ayah: _playerAyah,
            reciter: l10n.sampleReciter,
            speed: l10n.gallerySpeed,
            playing: _playing,
            progress: _playerValue,
            repeat: _playerRepeat,
            onRepeat: _none,
            onPrevious: _none,
            onPlayPause: _togglePlaying,
            onNext: _none,
            onSleepTimer: _none,
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionContinueCard,
          child: ContinueCard(
            surah: surah,
            meta: l10n.sampleMeta,
            progress: _continueProgress,
            onContinue: _none,
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionResourceRow,
          // ResourceRow/preview.html: a surface card with a line border,
          // radius 24, padded 8 by 24.
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(AppRadius.radiusCard),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.space2,
                horizontal: AppSpacing.space5,
              ),
              child: Column(
                children: [
                  ResourceRow(
                    title: l10n.sampleResourceTitle,
                    status: ResourceStatus.downloaded,
                    size: l10n.sampleSize,
                    onAction: _none,
                  ),
                  ResourceRow(
                    title: l10n.sampleResourceTitle,
                    status: ResourceStatus.downloading,
                    progress: _downloadProgress,
                  ),
                  ResourceRow(
                    title: l10n.sampleResourceTitle,
                    status: ResourceStatus.available,
                    size: l10n.sampleSize,
                    onAction: _none,
                    divider: false,
                  ),
                ],
              ),
            ),
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionReaderPlayerBar,
          child: ReaderPlayerBar(
            surah: surah,
            ayah: _barAyah,
            reciter: l10n.sampleReciter,
            playing: _playing,
            onPlayPause: _togglePlaying,
            onNext: _none,
          ),
        ),
      ],
    );
  }
}

void _none() {}
