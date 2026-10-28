import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/recitation_download.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/l10n/megabytes.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/small_button.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_block_state.dart';

/// One scope of a recitation (`AU-13`): `ResourceRow`'s layout with the
/// size still to download before it starts, a stop button while it runs,
/// and the failure of its last attempt under it. [title] is the scope's
/// name and [label] the same in words, for the progress bar's reader.
class ScopeRow extends StatelessWidget {
  const ScopeRow({
    required this.title,
    required this.label,
    required this.row,
    required this.onDownload,
    required this.onStop,
    required this.onDelete,
    this.divider = true,
    super.key,
  });

  final Widget title;
  final String label;
  final ScopeRowState row;
  final VoidCallback onDownload;
  final VoidCallback onStop;
  final VoidCallback onDelete;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final running =
        row.status == ScopeStatus.downloading ||
        row.status == ScopeStatus.waiting;
    final Widget status = switch (row.status) {
      ScopeStatus.available => Text(
        l10n.resourceAvailableMeta(megabytes(l10n, row.missingBytes)),
        style: scopeRowMetaStyle.copyWith(color: colors.inkMuted),
      ),
      ScopeStatus.downloaded => Row(
        spacing: AppSpacing.space1,
        children: [
          Icon(IconName.check, size: scopeRowCheckSize, color: colors.success),
          Flexible(
            child: Text(
              l10n.resourceDownloadedMeta(megabytes(l10n, row.totalBytes)),
              style: scopeRowDoneMetaStyle.copyWith(color: colors.success),
            ),
          ),
        ],
      ),
      ScopeStatus.waiting when row.waitingForWifi => Text(
        l10n.waitingForWifi,
        style: scopeRowMetaStyle.copyWith(color: colors.inkMuted),
      ),
      ScopeStatus.downloading || ScopeStatus.waiting => ProgressBar(
        value: row.progress,
        label: l10n.resourceDownloading(label),
      ),
    };
    final Widget end = running
        ? Row(
            spacing: AppSpacing.space3,
            children: [
              ExcludeSemantics(
                child: Text(
                  l10n.percentValue(arabicDigits(percentOf(row.progress))),
                  style: scopeRowPercentStyle.copyWith(color: colors.primary),
                ),
              ),
              SmallButton(
                label: l10n.resourceStop,
                onPressed: onStop,
                outlined: true,
              ),
            ],
          )
        : switch (row.status) {
            ScopeStatus.downloaded => SmallButton(
              label: l10n.resourceDelete,
              onPressed: onDelete,
              outlined: true,
            ),
            _ => SmallButton(
              label: l10n.resourceDownload,
              onPressed: onDownload,
            ),
          };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: colors.line)) : null,
      ),
      child: Padding(
        padding: scopeRowPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: scopeRowMainGap,
          children: [
            Row(
              spacing: AppSpacing.space4,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: scopeRowMainGap,
                    children: [title, status],
                  ),
                ),
                end,
              ],
            ),
            if (row.failure case final failure?)
              _failureAlert(l10n, failure, onDownload),
          ],
        ),
      ),
    );
  }
}

/// What a failed attempt shows. A file that failed its check offers to
/// fetch again; the others name what happened.
Widget _failureAlert(
  AppLocalizations l10n,
  RecitationDownloadFailure failure,
  VoidCallback onRetry,
) => switch (failure) {
  RecitationNoSpace() => IntegrityAlert(title: l10n.lowSpace),
  RecitationStoreFailed() => IntegrityAlert(title: l10n.downloadNotSaved),
  RecitationFileRejected() => IntegrityAlert(
    action: (label: l10n.resourceRedownload, onPressed: onRetry),
  ),
  _ => IntegrityAlert(title: l10n.connectionFailed),
};
