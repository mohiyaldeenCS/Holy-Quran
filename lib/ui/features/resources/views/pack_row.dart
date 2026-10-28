import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/l10n/megabytes.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/resource_row.dart';
import 'package:holyquran/ui/features/resources/view_models/pack_row_state.dart';

/// One pack (`OF-02`): its [ResourceRow], whose status line carries the
/// size, the catalogue's summary of its sources, the version and, for an
/// update, what it changes (`OF-06`); then its alert. The hairline under it
/// is the row's, drawn below the alert.
class PackRow extends StatelessWidget {
  const PackRow({
    required this.row,
    required this.onDownload,
    required this.onDelete,
    required this.onRedownload,
    this.title,
    this.divider = true,
    super.key,
  });

  final PackRowState row;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onRedownload;

  /// The row's name when it is not the pack's own: a recitation is named by
  /// its reciter and style (P1-33).
  final String? title;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResourceRow(
            title: title ?? entry.title,
            status: status,
            size: megabytes(l10n, entry.bytes),
            // CatalogueEntry refuses an empty source or change summary.
            details: [
              entry.source,
              arabicDigits(entry.version),
              if (row.state is ResourceUpdateAvailable) entry.changes,
            ],
            progress: row.progress,
            onAction: action,
            divider: false,
          ),
          if (row.alert case final alert?)
            Padding(
              padding: resourcesRowFootPadding,
              child: switch (alert) {
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
            ),
        ],
      ),
    );
  }
}
