import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/storage_bar.dart';

// Sample shares of a whole, in bytes: two categories that use some of it,
// one that uses none.
const int _sampleTotal = 1000;
const int _sampleTafsirs = 120;
const int _sampleRiwayat = 40;

/// The gallery's resource-manager section: the storage bar and the
/// integrity alert (PRD §7.7), on sample strings; the alert's own wording
/// awaits the owner (docs/plans/PHASE1.md, Appendix C).
class ResourcesGallery extends StatelessWidget {
  const ResourcesGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GallerySection(
      title: l10n.resourceManagerTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.space5,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.space3,
            children: [
              StorageBar(
                label: l10n.resourceCategoryTafsirs,
                usedBytes: _sampleTafsirs,
                totalBytes: _sampleTotal,
              ),
              StorageBar(
                label: l10n.resourceCategoryRiwayat,
                usedBytes: _sampleRiwayat,
                totalBytes: _sampleTotal,
              ),
              StorageBar(
                label: l10n.resourceCategoryPageMushaf,
                usedBytes: 0,
                totalBytes: _sampleTotal,
              ),
            ],
          ),
          IntegrityAlert(
            title: l10n.sampleRowLabel,
            body: l10n.sampleLongText,
            action: (label: l10n.resourceRedownload, onPressed: _none),
          ),
          IntegrityAlert(
            action: (label: l10n.resourceRedownload, onPressed: _none),
          ),
          IntegrityAlert(title: l10n.connectionFailed),
        ],
      ),
    );
  }
}

void _none() {}
