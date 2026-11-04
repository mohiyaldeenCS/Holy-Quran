import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/small_button.dart';

/// The three states of a resource the reference draws (D-088).
enum ResourceStatus { available, downloading, downloaded }

/// A row of the resource manager (`ResourceRow`, `.qk-resource`): the title
/// over its status, and at the end the action. The status is always in
/// words: «متاحة» with a download button, a track with the percentage while
/// it downloads, «تم التنزيل» with a check mark and a delete button.
///
/// A null [size] leaves the status word alone. [details] follow it on the
/// same line, each after the data separator « · », as the line writes its own
/// size; they are shown unchanged and not while downloading, which draws no
/// line. [progress] runs from 0 to 1.
/// [onAction] downloads or deletes; it is unused while downloading. [divider]
/// draws the bottom hairline, which the reference drops on the last row.
class ResourceRow extends StatelessWidget {
  const ResourceRow({
    required this.title,
    required this.status,
    this.size,
    this.details = const [],
    this.progress = 0,
    this.onAction,
    this.divider = true,
    super.key,
  }) : assert(status == ResourceStatus.downloading || onAction != null);

  final String title;
  final ResourceStatus status;
  final String? size;
  final List<String> details;
  final double progress;
  final VoidCallback? onAction;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final size = this.size;
    final fraction = progress.clamp(0.0, 1.0);
    String line(String state) => [state, ...details].join(l10n.dataSeparator);
    final Widget status = switch (this.status) {
      ResourceStatus.downloading => ProgressBar(
        value: fraction,
        label: l10n.resourceDownloading(title),
      ),
      ResourceStatus.downloaded => Row(
        spacing: AppSpacing.space1,
        children: [
          Icon(
            IconName.check,
            size: resourceRowCheckSize,
            color: colors.success,
          ),
          Flexible(
            child: Text(
              line(
                size == null
                    ? l10n.resourceDownloaded
                    : l10n.resourceDownloadedMeta(size),
              ),
              style: resourceRowDoneMetaStyle.copyWith(color: colors.success),
            ),
          ),
        ],
      ),
      ResourceStatus.available => Text(
        line(
          size == null
              ? l10n.resourceAvailable
              : l10n.resourceAvailableMeta(size),
        ),
        style: resourceRowMetaStyle.copyWith(color: colors.inkMuted),
      ),
    };
    final Widget end = switch (this.status) {
      // The track already reads this percentage as its value.
      ResourceStatus.downloading => ExcludeSemantics(
        child: Text(
          l10n.percentValue(arabicDigits((fraction * 100).round())),
          style: resourceRowPercentStyle.copyWith(color: colors.primary),
        ),
      ),
      ResourceStatus.downloaded => SmallButton(
        label: l10n.resourceDelete,
        onPressed: onAction!,
        outlined: true,
      ),
      ResourceStatus.available => SmallButton(
        label: l10n.resourceDownload,
        onPressed: onAction!,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? Border(bottom: BorderSide(color: colors.line)) : null,
      ),
      child: Padding(
        padding: resourceRowPadding,
        child: Row(
          spacing: AppSpacing.space4,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: resourceRowMainGap,
                children: [
                  Text(
                    title,
                    style: resourceRowTitleStyle.copyWith(color: colors.ink),
                  ),
                  status,
                ],
              ),
            ),
            end,
          ],
        ),
      ),
    );
  }
}
