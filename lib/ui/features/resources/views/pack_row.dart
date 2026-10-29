import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/l10n/megabytes.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/resource_row.dart';
import 'package:holyquran/ui/features/resources/view_models/pack_row_state.dart';
import 'package:holyquran/ui/features/resources/views/pack_row_alert.dart';

/// One pack (`OF-02`): its [ResourceRow], whose status line carries the
/// size, the catalogue's summary of its sources, the version and, for an
/// update, what it changes (`OF-06`); then its alert. The hairline under it
/// is the row's, drawn below the alert.
class PackRow extends StatelessWidget {
  const PackRow({
    required this.row,
    required this.onDownload,
    this.onDelete,
    required this.onRedownload,
    this.title,
    this.divider = true,
    super.key,
  });

  final PackRowState row;
  final VoidCallback onDownload;

  /// Null where the row offers no delete: a recitation's pack is deleted from
  /// the recitation's own header once installed, so its pack row never has
  /// one.
  final VoidCallback? onDelete;
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
            PackRowAlertView(alert: alert, onRedownload: onRedownload),
        ],
      ),
    );
  }
}
