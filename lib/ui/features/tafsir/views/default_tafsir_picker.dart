import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/radio_row.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';
import 'package:holyquran/ui/features/tafsir/view_models/tafsir_page.dart';

/// The list the default tafsir is chosen from (`TF-01`): the downloaded
/// books as a single-choice list, one of them chosen, apart from the tafsirs
/// that are only available. An available tafsir is named, not chosen; it is
/// downloaded from the resource manager first. A downloaded book that failed
/// its checks has no title and shows the integrity alert in its place.
class DefaultTafsirPicker extends StatelessWidget {
  const DefaultTafsirPicker({
    required this.downloaded,
    required this.available,
    required this.choiceNotSaved,
    required this.onChoose,
    super.key,
  });

  final List<TafsirChoice> downloaded;
  final List<String> available;

  /// Whether the last choice could not be saved.
  final bool choiceNotSaved;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final heading = AppTextStyles.bodyStrong.copyWith(color: colors.inkMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space2,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.defaultTafsirLabel,
            style: AppTextStyles.sectionTitle.copyWith(color: colors.ink),
          ),
        ),
        if (choiceNotSaved) IntegrityAlert(title: l10n.userDataNotSaved),
        if (downloaded.isNotEmpty) ...[
          Semantics(
            header: true,
            child: Text(l10n.resourcesDownloaded, style: heading),
          ),
          Semantics(
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final choice in downloaded)
                  switch (choice.title) {
                    final title? => RadioRow(
                      key: ValueKey(choice.packId),
                      selected: choice.chosen,
                      onTap: () => onChoose(choice.packId),
                      child: TafsirText(title, style: RadioRow.labelStyle),
                    ),
                    null => IntegrityAlert(
                      key: ValueKey(choice.packId),
                      title: l10n.integrityPackTitle,
                      body: l10n.integrityPackBody,
                    ),
                  },
              ],
            ),
          ),
        ],
        if (available.isNotEmpty) ...[
          Semantics(
            header: true,
            child: Text(l10n.resourcesAvailable, style: heading),
          ),
          for (final title in available)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  title,
                  style: AppTextStyles.body.copyWith(color: colors.inkMuted),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
