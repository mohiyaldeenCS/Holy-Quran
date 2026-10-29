import 'dart:async';

import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/l10n/megabytes.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_block_state.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_section_view_model.dart';
import 'package:holyquran/ui/features/resources/views/pack_row.dart';
import 'package:holyquran/ui/features/resources/views/sections/delete_recitation_sheet.dart';
import 'package:holyquran/ui/features/resources/views/sections/recitation_header.dart';
import 'package:holyquran/ui/features/resources/views/sections/scope_row.dart';

/// One listed recitation: its head, named by the reciter and style the
/// catalogue gives, and under it, once the pack is installed, the quality
/// (`AU-14`) and the whole, surahs and juz it can be downloaded in
/// (`AU-13`). Deleting the recitation asks first, stating the size.
class RecitationBlock extends StatelessWidget {
  const RecitationBlock({
    required this.block,
    required this.viewModel,
    super.key,
  });

  final RecitationBlockState block;
  final RecitationSectionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = block.id;
    final details = block.recitation.recitation;
    final title = [details.reciter, details.style].join(l10n.dataSeparator);
    final whole = block.whole;
    final quality = block.quality;
    final installed = switch (block.pack.state) {
      ResourceDownloaded() || ResourceUpdateAvailable() => true,
      ResourceAvailable() || ResourceDownloading() => false,
    };
    final hasTabs = block.surahs.isNotEmpty && block.juz.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: recitationPanelGap,
      children: [
        if (installed)
          RecitationHeader(
            title: title,
            block: block,
            onDelete: block.hasJob
                ? null
                : () => unawaited(_confirmDelete(context)),
            onRedownload: () => unawaited(viewModel.redownloadPack(id)),
            divider: !block.ready,
          )
        else
          PackRow(
            row: block.pack,
            title: title,
            onDownload: () => viewModel.downloadPack(id),
            onRedownload: () => unawaited(viewModel.redownloadPack(id)),
            divider: false,
          ),
        if (block.choosesQuality && quality != null)
          LevelSwitch(
            options: [
              for (final kbps in block.qualities)
                l10n.recitationQualityKbps(arabicDigits(kbps)),
            ],
            selectedIndex: block.qualities.indexOf(quality),
            onChanged: (index) =>
                viewModel.selectQuality(id, block.qualities[index]),
            semanticLabel: l10n.qualityLabel,
          ),
        if (hasTabs)
          LevelSwitch(
            options: [l10n.indexTabSurahs, l10n.indexTabJuz],
            selectedIndex: block.tab.index,
            onChanged: (index) =>
                viewModel.selectTab(id, ScopeTab.values[index]),
            semanticLabel: l10n.recitationScopeLabel,
          ),
        if (whole != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(context, whole, last: block.rows.isEmpty),
              for (final (index, row) in block.rows.indexed)
                _row(context, row, last: index == block.rows.length - 1),
            ],
          ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final size = megabytes(l10n, await viewModel.sizeToDelete(block.id));
    if (!context.mounted) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface.withValues(alpha: 0),
      elevation: 0,
      barrierColor: context.colors.scrim,
      builder: (context) => DeleteRecitationSheet(size: size),
    );
    if (confirmed ?? false) await viewModel.deleteRecitation(block.id);
  }

  Widget _row(BuildContext context, ScopeRowState row, {required bool last}) {
    final l10n = AppLocalizations.of(context);
    final style = scopeRowTitleStyle.copyWith(color: context.colors.ink);
    final (Widget title, String label) = switch (row.kind) {
      ScopeKind.whole => (
        Text(l10n.recitationDownloadWhole, style: style),
        l10n.recitationDownloadWhole,
      ),
      ScopeKind.juz => (
        Text(l10n.juzLabel(arabicDigits(row.number)), style: style),
        l10n.juzLabel(arabicDigits(row.number)),
      ),
      // The view model leaves out a surah the base pack does not name.
      ScopeKind.surah => (
        SurahName(
          viewModel.surahName(row.number)!,
          style: style,
          format: SurahNameFormat.titled,
        ),
        SurahName.span(
          viewModel.surahName(row.number)!,
          format: SurahNameFormat.titled,
          style: style,
          l10n: l10n,
        ).text!,
      ),
    };
    return ScopeRow(
      key: ValueKey(row.key),
      title: title,
      label: label,
      row: row,
      canDelete: !block.hasJob,
      onDownload: () => viewModel.download(block.id, row),
      onStop: () => viewModel.stop(row),
      onDelete: () => unawaited(viewModel.delete(block.id, row)),
      divider: !last,
    );
  }
}
