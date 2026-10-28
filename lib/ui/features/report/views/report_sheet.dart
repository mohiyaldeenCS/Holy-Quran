import 'package:flutter/material.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/report_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/features/report/view_models/report_view_model.dart';
import 'package:provider/provider.dart';

/// The «أبلغ عن خطأ» sheet (O-17), an extension on the identity's bottom
/// sheet: the ayah reported and, for an entry, its pack's id, version and
/// source as the manifest gives them. Its title, its other lines and the
/// send action wait for their wording (PHASE1.md, Appendix B and C) and the
/// mail service D-127 calls for.
class ReportSheet extends StatelessWidget {
  const ReportSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final viewModel = context.watch<ReportViewModel>();
    final surahName = viewModel.surahName;
    final pack = viewModel.pack;
    final sourceName = pack?.sourceName;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
        borderRadius: ReportMetrics.sheetRadius,
        boxShadow: context.shadows.shadowSheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: ReportMetrics.sheetPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: ReportMetrics.sheetGap,
            children: [
              Center(
                child: Container(
                  width: ReportMetrics.handleSize.width,
                  height: ReportMetrics.handleSize.height,
                  decoration: BoxDecoration(
                    color: colors.lineStrong,
                    borderRadius: ReportMetrics.handleRadius,
                  ),
                ),
              ),
              if (surahName != null)
                SurahName(
                  surahName,
                  format: SurahNameFormat.withAyah,
                  ayah: viewModel.address.ayah,
                  style: AppTextStyles.bodyStrong.copyWith(color: colors.ink),
                ),
              // One data line, its items apart by the identity's middle dot
              // (docs/DESIGN_SYSTEM.md, Ground rules, 6). The Latin id keeps
              // its own left-to-right run inside the line.
              if (pack != null)
                Text(
                  [
                    pack.id,
                    arabicDigits(pack.version),
                    ?sourceName,
                  ].join(AppLocalizations.of(context).dataSeparator),
                  style: AppTextStyles.secondary.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
