import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/features/resources/view_models/first_use_tafsir_view_model.dart';
import 'package:holyquran/ui/features/resources/views/pack_row.dart';

/// The sheet that offers the short tafsir at the first use of tafsir
/// (`TF-06`): the sheet's surface and handle (`.qk-sheet`) over the pack's
/// row.
class FirstUseTafsirSheet extends StatelessWidget {
  const FirstUseTafsirSheet({required this.viewModel, super.key});

  final FirstUseTafsirViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
        borderRadius: resourcesSheetRadius,
        boxShadow: context.shadows.shadowSheet,
      ),
      child: Padding(
        padding: resourcesSheetPadding,
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final row = viewModel.row;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: resourcesSheetGap,
              children: [
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.lineStrong,
                      borderRadius: resourcesSheetHandleRadius,
                    ),
                    child: SizedBox.fromSize(size: resourcesSheetHandleSize),
                  ),
                ),
                if (viewModel.unreachable)
                  IntegrityAlert(
                    title: AppLocalizations.of(context).connectionFailed,
                  ),
                if (row != null)
                  PackRow(
                    row: row,
                    onDownload: () => unawaited(viewModel.download()),
                    onDelete: viewModel.delete,
                    onRedownload: () => unawaited(viewModel.download()),
                    divider: false,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
