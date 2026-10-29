import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/tafsir_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/features/tafsir/view_models/tafsir_view_model.dart';
import 'package:holyquran/ui/features/tafsir/views/default_tafsir_picker.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_body.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_steps.dart';

/// «قارئ التفسير» (`TF-02`, `TF-03`): the full screen of the study tab, laid
/// out as «خطة الحفظ» of the Search board, which the identity does not
/// extend to a tafsir. A back button and the title, then the ayah above its
/// passage and the list the default tafsir is chosen from; the steps between
/// ayat stand beneath.
///
/// A null [viewModel] means the app provides no text pack yet; the screen
/// then shows its title alone.
class TafsirReaderScreen extends StatelessWidget {
  const TafsirReaderScreen({
    required this.viewModel,
    required this.onOfferDownload,
    super.key,
  });

  final TafsirViewModel? viewModel;

  /// Opens the offer of the first download (`TF-06`); null when there is
  /// nothing to open.
  final VoidCallback? onOfferDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final viewModel = this.viewModel;
    return ColoredBox(
      color: colors.ground,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: tafsirHeaderPadding,
              child: Row(
                spacing: tafsirHeaderGap,
                children: [
                  IconButton(
                    icon: IconName.previous,
                    label: l10n.back,
                    tone: IconButtonTone.tint,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.tafsirReaderTitle,
                        style: tafsirTitleStyle.copyWith(color: colors.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: viewModel == null
                  ? const SizedBox.shrink()
                  : ListenableBuilder(
                      listenable: viewModel,
                      builder: (context, _) => _Content(
                        viewModel: viewModel,
                        onOfferDownload: onOfferDownload,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.viewModel, required this.onOfferDownload});

  final TafsirViewModel viewModel;
  final VoidCallback? onOfferDownload;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.loaded) return const SizedBox.shrink();
    final picks =
        viewModel.downloaded.isNotEmpty || viewModel.available.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            // A new ayah starts at the top.
            key: ValueKey(viewModel.address),
            padding: tafsirBodyPadding,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.space5,
                children: [
                  TafsirBody(
                    viewModel: viewModel,
                    onOfferDownload: onOfferDownload,
                  ),
                  if (picks)
                    DefaultTafsirPicker(
                      downloaded: viewModel.downloaded,
                      available: viewModel.available,
                      choiceNotSaved: viewModel.choiceNotSaved,
                      onChoose: (packId) => unawaited(viewModel.choose(packId)),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (viewModel.page != null)
          Padding(
            padding: tafsirStepsPadding,
            child: TafsirSteps(
              previous: viewModel.previous,
              next: viewModel.next,
              onStep: (ayah) => unawaited(viewModel.goTo(ayah)),
            ),
          ),
      ],
    );
  }
}
