import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/storage_bar.dart';
import 'package:holyquran/ui/features/resources/view_models/resources_view_model.dart';
import 'package:holyquran/ui/features/resources/views/pack_row.dart';

/// One category of the resource manager (`OF-01`): its name, the space its
/// packs use out of [storageBytes] (`OF-03`), and its packs.
class PackCategorySection extends StatelessWidget {
  const PackCategorySection({
    required this.section,
    required this.storageBytes,
    required this.viewModel,
    super.key,
  });

  final PackSection section;
  final int storageBytes;
  final ResourcesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final title = categoryTitle(AppLocalizations.of(context), section.kind);
    final rows = section.rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space2,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(
              color: context.colors.ink,
            ),
          ),
        ),
        StorageBar(
          label: title,
          usedBytes: section.usedBytes,
          totalBytes: storageBytes,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, row) in rows.indexed)
              PackRow(
                key: ValueKey(row.entry.id),
                row: row,
                onDownload: () => viewModel.download(row.entry.id),
                onDelete: () => viewModel.delete(row.entry.id),
                onRedownload: () =>
                    unawaited(viewModel.redownload(row.entry.id)),
                divider: index < rows.length - 1,
              ),
          ],
        ),
      ],
    );
  }
}

/// The category name of `OF-01` that holds packs of [kind]: a text pack is
/// the text of a riwaya.
String categoryTitle(AppLocalizations l10n, PackKind kind) => switch (kind) {
  PackKind.tafsir => l10n.resourceCategoryTafsirs,
  PackKind.text => l10n.resourceCategoryRiwayat,
  PackKind.recitation => l10n.resourceCategoryRecitations,
};
