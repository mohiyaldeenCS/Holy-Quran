import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_block_state.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_section_view_model.dart';
import 'package:holyquran/ui/features/resources/views/pack_row.dart';
import 'package:holyquran/ui/features/resources/views/sections/scope_row.dart';

/// One listed recitation: its pack row, named by the reciter and style the
/// catalogue gives, and under it, once the pack is installed, the quality
/// (`AU-14`) and the whole, surahs and juz it can be downloaded in
/// (`AU-13`).
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
    final whole = block.whole;
    final quality = block.quality;
    final hasTabs = block.surahs.isNotEmpty && block.juz.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: recitationPanelGap,
      children: [
        PackRow(
          row: block.pack,
          title: [details.reciter, details.style].join(l10n.dataSeparator),
          onDownload: () => viewModel.downloadPack(id),
          onDelete: () => viewModel.deleteRecitation(id),
          onRedownload: () => viewModel.redownloadPack(id),
          divider: !block.ready,
        ),
        if (block.choosesQuality && quality != null)
          ModeChips(
            label: l10n.qualityLabel,
            options: [
              for (final kbps in block.qualities)
                l10n.recitationQualityKbps(arabicDigits(kbps)),
            ],
            selectedIndex: block.qualities.indexOf(quality),
            onChanged: (index) =>
                viewModel.selectQuality(id, block.qualities[index]),
          ),
        if (hasTabs)
          ModeChips(
            label: l10n.resourceCategoryRecitations,
            options: [l10n.indexTabSurahs, l10n.indexTabJuz],
            selectedIndex: block.tab.index,
            onChanged: (index) =>
                viewModel.selectTab(id, ScopeTab.values[index]),
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
      ScopeKind.surah => switch (viewModel.surahName(row.number)) {
        final name? => (
          SurahName(name, style: style, format: SurahNameFormat.titled),
          SurahName.span(
            name,
            format: SurahNameFormat.titled,
            style: style,
            l10n: l10n,
          ).text!,
        ),
        null => (const SizedBox.shrink(), ''),
      },
    };
    return ScopeRow(
      key: ValueKey(row.key),
      title: title,
      label: label,
      row: row,
      onDownload: () => viewModel.download(block.id, row),
      onStop: () => viewModel.stop(row),
      onDelete: () => viewModel.delete(block.id, row),
      divider: !last,
    );
  }
}
