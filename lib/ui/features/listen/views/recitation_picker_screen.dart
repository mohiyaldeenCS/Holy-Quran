import 'package:flutter/widgets.dart' hide Icon;
import 'package:go_router/go_router.dart';
import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/player_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/recitation_card.dart';
import 'package:holyquran/ui/features/listen/view_models/recitation_picker_view_model.dart';

/// The recitation picker (`AU-01`), an extension screen that follows the
/// listen screen of the Screens2 board: each recitation is the board's
/// reciter card, with its style, download state and «توقيت كلمات» where it
/// has word timing. With no recitation the list is empty: the empty
/// state's sentence is not written yet.
class RecitationPickerScreen extends StatelessWidget {
  const RecitationPickerScreen({required this.viewModel, super.key});

  final RecitationPickerViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: PlayerMetrics.headerPadding,
            child: Row(
              spacing: AppSpacing.space2,
              children: [
                IconButton(
                  icon: IconName.previous,
                  label: l10n.back,
                  tone: IconButtonTone.tint,
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Text(
                    l10n.resourceCategoryRecitations,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: context.colors.ink,
                    ),
                  ),
                ),
                const SizedBox.square(dimension: AppSizes.targetMin),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) {
                final listings = viewModel.listings;
                return ListView.separated(
                  padding: PlayerMetrics.bodyPadding,
                  itemCount: listings.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.space3),
                  itemBuilder: (context, index) {
                    final (:recitation, :state) = listings[index];
                    final details = recitation.recitation;
                    return RecitationCard(
                      reciter: details.reciter,
                      details: [
                        details.style,
                        ?_stateWord(l10n, state),
                        if (details.hasWordTiming) l10n.wordTimingTag,
                      ].join(l10n.dataSeparator),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String? _stateWord(AppLocalizations l10n, ResourceState? state) =>
    switch (state) {
      ResourceDownloaded() ||
      ResourceUpdateAvailable() => l10n.resourceDownloaded,
      ResourceAvailable() => l10n.resourceAvailable,
      ResourceDownloading(:final percent?) => l10n.percentValue(
        arabicDigits(percent),
      ),
      ResourceDownloading() || null => null,
    };
