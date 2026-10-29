import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/features/tafsir/view_models/tafsir_view_model.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_body.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_steps.dart';

/// The tafsir sheet of an ayah (`TF-02`), opened from the ayah tools: the
/// ayah above its passage, the steps between ayat, and the way to the full
/// reader. It takes the frame of the identity's sheets.
class TafsirSheet extends StatelessWidget {
  const TafsirSheet({
    required this.viewModel,
    required this.onOfferDownload,
    required this.onOpenReader,
    super.key,
  });

  final TafsirViewModel viewModel;
  final VoidCallback onOfferDownload;

  /// Opens the full reader at the ayah shown.
  final VoidCallback onOpenReader;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      if (!viewModel.loaded) return const CopySheetFrame(children: []);
      return CopySheetFrame(
        children: [
          TafsirBody(viewModel: viewModel, onOfferDownload: onOfferDownload),
          if (viewModel.page != null)
            TafsirSteps(
              previous: viewModel.previous,
              next: viewModel.next,
              onStep: (ayah) => unawaited(viewModel.goTo(ayah)),
            ),
          if (viewModel.page != null)
            Button(
              label: AppLocalizations.of(context).tafsirReaderTitle,
              variant: ButtonVariant.text,
              onPressed: onOpenReader,
            ),
        ],
      );
    },
  );
}
