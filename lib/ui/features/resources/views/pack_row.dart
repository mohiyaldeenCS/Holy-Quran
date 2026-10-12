import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/resource_row.dart';
import 'package:holyquran/ui/features/resources/view_models/pack_row_state.dart';

/// One pack (`OF-02`): its [ResourceRow], then the catalogue's summary of
/// its sources, what an update changes (`OF-06`) and its alert. The
/// hairline under it is the row's, drawn below these lines.
class PackRow extends StatelessWidget {
  const PackRow({
    required this.row,
    required this.onDownload,
    required this.onDelete,
    required this.onRedownload,
    this.divider = true,
    super.key,
  });

  final PackRowState row;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onRedownload;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final entry = row.entry;
    final (status, action) = switch (row.state) {
      ResourceAvailable() => (ResourceStatus.available, onDownload),
      ResourceDownloading() => (ResourceStatus.downloading, null),
      ResourceDownloaded() ||
      ResourceUpdateAvailable() => (ResourceStatus.downloaded, onDelete),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: colors.line)) : null,
      ),
      child: Padding(
        padding: resourcesRowFootPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResourceRow(
              title: entry.title,
              status: status,
              progress: row.progress,
              onAction: action,
              divider: false,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: resourcesRowLineGap,
              children: [
                Text(
                  entry.source,
                  style: AppTextStyles.secondary.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
                if (row.state is ResourceUpdateAvailable)
                  Text(
                    entry.changes,
                    style: AppTextStyles.secondary.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                if (row.alert case final alert?)
                  switch (alert) {
                    // Its title and body await their wording (PHASE1.md,
                    // Appendix C); the action names what it does.
                    PackRowAlert.integrity => IntegrityAlert(
                      action: (
                        label: l10n.resourceRedownload,
                        onPressed: onRedownload,
                      ),
                    ),
                    PackRowAlert.connection => IntegrityAlert(
                      title: l10n.connectionFailed,
                    ),
                  },
              ],
            ),
          ],
        ),
      ),
    );
  }
}
