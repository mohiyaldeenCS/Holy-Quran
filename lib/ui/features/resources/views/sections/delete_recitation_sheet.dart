import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';

/// The sheet that asks before a downloaded recitation is deleted, stating
/// the size it frees (owner, 2026-10-29). It closes with true when the user
/// confirms and with false when they leave. It is the identity's sheet
/// frame, as the copy sheet uses it, with the identity's buttons.
class DeleteRecitationSheet extends StatelessWidget {
  const DeleteRecitationSheet({required this.size, super.key});

  /// The size, already written with its unit.
  final String size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CopySheetFrame(
      children: [
        CopySheetTitle(l10n.deleteRecitationTitle),
        Text(
          l10n.downloadSize(size),
          style: AppTextStyles.bodyStrong.copyWith(color: context.colors.ink),
        ),
        Text(
          l10n.deletePackBody,
          style: AppTextStyles.body.copyWith(color: context.colors.ink),
        ),
        CopySheetFrame.action(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.space2,
            children: [
              Button(
                label: l10n.resourceDelete,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              Button(
                label: l10n.resourceCancel,
                variant: ButtonVariant.outline,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
