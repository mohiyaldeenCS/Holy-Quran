import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/tafsir_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/tafsir_text.dart';
import 'package:holyquran/ui/features/tafsir/view_models/tafsir_page.dart';

/// The list the default tafsir is chosen from (`TF-01`): the downloaded
/// books, one of them marked, apart from the tafsirs that are only
/// available. An available tafsir is named, not chosen; it is downloaded
/// from the resource manager first.
class DefaultTafsirPicker extends StatelessWidget {
  const DefaultTafsirPicker({
    required this.downloaded,
    required this.available,
    required this.onChoose,
    super.key,
  });

  final List<TafsirChoice> downloaded;
  final List<String> available;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final heading = AppTextStyles.bodyStrong.copyWith(color: colors.inkMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.defaultTafsirLabel,
            style: AppTextStyles.sectionTitle.copyWith(color: colors.ink),
          ),
        ),
        if (downloaded.isNotEmpty) ...[
          Text(l10n.resourcesDownloaded, style: heading),
          Semantics(
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final choice in downloaded)
                  _ChoiceRow(
                    key: ValueKey(choice.packId),
                    choice: choice,
                    onPressed: () => onChoose(choice.packId),
                  ),
              ],
            ),
          ),
        ],
        if (available.isNotEmpty) ...[
          Text(l10n.resourcesAvailable, style: heading),
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

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.choice, required this.onPressed, super.key});

  final TafsirChoice choice;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The mark is a shape as well as a colour: the check beside the title.
    return Semantics(
      container: true,
      selected: choice.chosen,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: tafsirChoiceFocusRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
          child: Row(
            spacing: AppSpacing.space3,
            children: [
              Expanded(
                child: TafsirText(choice.title, style: AppTextStyles.body),
              ),
              if (choice.chosen) Icon(IconName.check, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
