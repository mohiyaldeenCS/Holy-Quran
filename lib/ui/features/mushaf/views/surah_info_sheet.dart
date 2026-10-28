import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/reader_screen_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/surah_header.dart';
import 'package:holyquran/ui/features/mushaf/view_models/surah_info_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/surah_info_text.dart';

/// «مقدمة السورة» (`RD-17`): the surah's header at its large size with the
/// facts of its information line, on the identity's bottom sheet
/// (`.qk-sheet`). A surah introduction text is content from a source and is
/// not built here.
class SurahInfoSheet extends StatelessWidget {
  const SurahInfoSheet({required this.viewModel, super.key});

  final SurahInfoViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final info = viewModel.info;
        if (info == null) return const SizedBox.shrink();
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.line)),
            borderRadius: ReaderScreenMetrics.sheetRadius,
            boxShadow: context.shadows.shadowSheet,
          ),
          child: SafeArea(
            top: false,
            // Scrolls only when large text outgrows a short screen.
            child: SingleChildScrollView(
              child: Padding(
                padding: ReaderScreenMetrics.sheetPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: ReaderScreenMetrics.sheetGap,
                  children: [
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.lineStrong,
                          borderRadius: ReaderScreenMetrics.handleRadius,
                        ),
                        child: SizedBox.fromSize(
                          size: ReaderScreenMetrics.handleSize,
                        ),
                      ),
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.surahIntroTitle,
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: colors.ink,
                        ),
                      ),
                    ),
                    SurahHeader(
                      name: info.name,
                      size: SurahHeaderSize.lg,
                      info: surahInfoText(l10n, info),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
