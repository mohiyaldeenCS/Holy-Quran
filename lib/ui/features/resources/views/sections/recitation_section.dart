import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/storage_bar.dart';
import 'package:holyquran/ui/core/widgets/switch.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_section_view_model.dart';
import 'package:holyquran/ui/features/resources/views/sections/recitation_block.dart';

/// The recitations of the resource manager (`OF-01`, `AU-13`): the category
/// name, the space its recitations use out of [storageBytes] (`OF-03`), the
/// Wi-Fi-only choice that every download below follows, and each listed
/// recitation. Nothing shows while no recitation is listed.
class RecitationSection extends StatelessWidget {
  const RecitationSection({
    required this.viewModel,
    required this.storageBytes,
    super.key,
  });

  final RecitationSectionViewModel viewModel;
  final int storageBytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final blocks = viewModel.blocks;
        if (blocks.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.space2,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.resourceCategoryRecitations,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: context.colors.ink,
                ),
              ),
            ),
            StorageBar(
              label: l10n.resourceCategoryRecitations,
              usedBytes: viewModel.usedBytes,
              totalBytes: storageBytes,
            ),
            Switch(
              label: l10n.wifiOnly,
              value: viewModel.wifiOnly,
              onChanged: (value) => viewModel.wifiOnly = value,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: resourcesBlockGap,
              children: [
                for (final block in blocks)
                  RecitationBlock(
                    key: ValueKey(block.id),
                    block: block,
                    viewModel: viewModel,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
