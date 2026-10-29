import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/small_button.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_block_state.dart';
import 'package:holyquran/ui/features/resources/views/pack_row_alert.dart';

/// The head of an installed recitation: its name over how much of it is on
/// the device, and the action that deletes it (`AU-13`). It is
/// `ResourceRow`'s layout, but its state is the recitation's, not the
/// pack's: a recitation is downloaded once its whole is, and partly
/// downloaded before that. [onDelete] is null while a job of the recitation
/// runs.
class RecitationHeader extends StatelessWidget {
  const RecitationHeader({
    required this.title,
    required this.block,
    required this.onDelete,
    required this.onRedownload,
    this.divider = true,
    super.key,
  });

  final String title;
  final RecitationBlockState block;
  final VoidCallback? onDelete;
  final VoidCallback onRedownload;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final entry = block.pack.entry;
    final status = block.status;
    final update = block.pack.state is ResourceUpdateAvailable;
    final word = switch (status) {
      RecitationStatus.downloaded => l10n.resourceDownloaded,
      RecitationStatus.partial => l10n.recitationPartial,
      RecitationStatus.available => l10n.resourceAvailable,
    };
    final line = [
      word,
      entry.source,
      arabicDigits(entry.version),
      if (update) ...[l10n.updateAvailable, entry.changes],
    ].join(l10n.dataSeparator);
    final onDelete = this.onDelete;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: colors.line)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: scopeRowPadding,
            child: Row(
              spacing: AppSpacing.space4,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: scopeRowMainGap,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: scopeRowTitleStyle.copyWith(color: colors.ink),
                        ),
                      ),
                      if (status == RecitationStatus.downloaded)
                        Row(
                          spacing: AppSpacing.space1,
                          children: [
                            Icon(
                              IconName.check,
                              size: scopeRowCheckSize,
                              color: colors.success,
                            ),
                            Flexible(
                              child: Text(
                                line,
                                style: scopeRowDoneMetaStyle.copyWith(
                                  color: colors.success,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          line,
                          style: scopeRowMetaStyle.copyWith(
                            color: colors.inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  Semantics(
                    container: true,
                    button: true,
                    label: l10n.resourceDeleteNamed(title),
                    onTap: onDelete,
                    excludeSemantics: true,
                    child: SmallButton(
                      label: l10n.resourceDelete,
                      onPressed: onDelete,
                      outlined: true,
                    ),
                  ),
              ],
            ),
          ),
          if (block.pack.alert case final alert?)
            PackRowAlertView(alert: alert, onRedownload: onRedownload),
        ],
      ),
    );
  }
}
