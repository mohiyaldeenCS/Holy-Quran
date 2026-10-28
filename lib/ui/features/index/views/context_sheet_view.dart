import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/sheet_needs.dart';
import 'package:holyquran/ui/core/l10n/ayah_count.dart';
import 'package:holyquran/ui/core/widgets/context_sheet.dart';
import 'package:holyquran/ui/features/index/view_models/context_sheet_view_model.dart';

/// The ayah-context sheet of the ayah in [viewModel] (`NV-05`). «افتح في
/// المصحف» opens the reader at that ayah.
class ContextSheetView extends StatelessWidget {
  const ContextSheetView({required this.viewModel, super.key});

  final ContextSheetViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        // The pack can stop serving while the sheet is open; then it closes.
        final surahName = viewModel.surahName;
        if (surahName == null) {
          return SheetNeeds(available: (_) => false, child: const SizedBox());
        }
        return ContextSheet(
          surahName: surahName,
          ayahNumber: viewModel.address.ayah,
          amounts: [
            for (final amount in viewModel.amounts)
              switch (amount) {
                null => l10n.contextSurah,
                1 => l10n.contextOneAyah,
                final count => ayahCount(l10n, count),
              },
          ],
          amount: viewModel.amount,
          onAmountSelected: viewModel.select,
          passage: viewModel.passage,
          onOpen: () => context.go(Routes.mushafRead(viewModel.address)),
        );
      },
    );
  }
}
