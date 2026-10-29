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
/// size still to download before it starts, a stop button while it waits or
/// runs, and the failure of its last attempt under it. [title] is the
/// scope's name and [label] the same in words, which names each button for
/// a screen reader. A scope that is partly on the device offers to resume
/// it. [canDelete] is false while a job of the recitation runs.
class ScopeRow extends StatelessWidget {
  const ScopeRow({
    required this.title,
    required this.label,
    required this.row,
    required this.canDelete,
    required this.onDownload,
    required this.onStop,
    required this.onDelete,
    this.divider = true,
    super.key,
  });

  final Widget title;
  final String label;
  final ScopeRowState row;
  final bool canDelete;
  final VoidCallback onDownload;
  final VoidCallback onStop;
  final VoidCallback onDelete;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    Widget meta(String text) =>
        Text(text, style: scopeRowMetaStyle.copyWith(color: colors.inkMuted));
    final Widget status = switch (row.status) {
      ScopeStatus.available => meta(
        l10n.resourceAvailableMeta(megabytes(l10n, row.missingBytes)),
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
      ScopeStatus.queued => meta(l10n.resourceQueued),
      ScopeStatus.waiting => meta(
        row.waitingForWifi ? l10n.waitingForWifi : l10n.waitingForNetwork,
      ),
      ScopeStatus.downloading => ProgressBar(
        value: row.progress,
        label: l10n.resourceDownloading(label),
      ),
    };
    final stop = _button(
      l10n.resourceStop,
      l10n.resourceStopNamed(label),
      onStop,
    );
    final Widget? end = switch (row.status) {
      ScopeStatus.downloading => Row(
        spacing: AppSpacing.space3,
        children: [
          ExcludeSemantics(
            child: Text(
              l10n.percentValue(arabicDigits(percentOf(row.progress))),
              style: scopeRowPercentStyle.copyWith(color: colors.primary),
            ),
          ),
          stop,
        ],
      ),
      ScopeStatus.queued || ScopeStatus.waiting => stop,
      ScopeStatus.downloaded =>
        canDelete
            ? _button(
                l10n.resourceDelete,
                l10n.resourceDeleteNamed(label),
                onDelete,
              )
            : null,
      ScopeStatus.available when row.partial => _button(
        l10n.resourceResume,
        l10n.resourceResumeNamed(label),
        onDownload,
        filled: true,
      ),
      ScopeStatus.available => _button(
        l10n.resourceDownload,
        l10n.resourceDownloadNamed(label),
        onDownload,
        filled: true,
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
                ?end,
              ],
            ),
            if (row.failure case final failure?)
              _failureAlert(l10n, failure, onDownload),
          ],
        ),
      ),
    );
  }

  /// A small button that a screen reader hears by [spoken], which names the
  /// scope, where [text] is all that is drawn. Stop and delete are outlined.
  static Widget _button(
    String text,
    String spoken,
    VoidCallback onPressed, {
    bool filled = false,
  }) => Semantics(
    container: true,
    button: true,
    label: spoken,
    onTap: onPressed,
    excludeSemantics: true,
    child: SmallButton(label: text, onPressed: onPressed, outlined: !filled),
  );
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
