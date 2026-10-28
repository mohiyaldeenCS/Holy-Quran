import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/search_hit.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/l10n/ayah_count.dart';
import 'package:holyquran/ui/core/metrics/search_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';
import 'package:holyquran/ui/core/widgets/search_summary.dart';
import 'package:holyquran/ui/features/search/view_models/search_view_model.dart';

/// What was searched and how many results, with the order control (`SR-04`,
/// `SR-05`), or the sentence that nothing was found.
class SearchSummaryLine extends StatelessWidget {
  const SearchSummaryLine({required this.viewModel, super.key});

  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (viewModel.ayat == 0) {
      return Text(
        l10n.noSearchResults,
        style: AppTextStyles.secondary.copyWith(color: context.colors.inkMuted),
      );
    }
    final places = l10n.searchPlaces(
      viewModel.occurrences,
      arabicDigits(viewModel.occurrences),
    );
    return Padding(
      padding: SearchMetrics.summary,
      child: SearchSummary(
        title: viewModel.query ?? '',
        count: l10n.searchResultCount(places, ayahCount(l10n, viewModel.ayat)),
        sortLabel: switch (viewModel.order) {
          SearchOrder.mushaf => l10n.searchSortMushafOrder,
          SearchOrder.closeness => l10n.searchSortNearest,
          SearchOrder.frequency => l10n.searchSortFrequent,
        },
        onSort: viewModel.nextOrder,
      ),
    );
  }
}

/// The result cards as a sliver, each read from the pack when it is first
/// built. The cards that are shown whole are the view model's, so they stay
/// whole when scrolled away and back.
class SearchResultsSliver extends StatelessWidget {
  const SearchResultsSliver({required this.viewModel, super.key});

  final SearchViewModel viewModel;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: SearchMetrics.results,
    sliver: SliverList.separated(
      itemCount: viewModel.cardCount,
      separatorBuilder: (context, index) =>
          const SizedBox(height: SearchMetrics.resultGap),
      itemBuilder: (context, index) => _ResultItem(
        key: ValueKey(viewModel.ayahAt(index)),
        viewModel: viewModel,
        index: index,
      ),
    ),
  );
}

class _ResultItem extends StatefulWidget {
  const _ResultItem({required this.viewModel, required this.index, super.key});

  final SearchViewModel viewModel;
  final int index;

  @override
  State<_ResultItem> createState() => _ResultItemState();
}

class _ResultItemState extends State<_ResultItem> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.loadCard(widget.index);
  }

  @override
  void didUpdateWidget(_ResultItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.viewModel.loadCard(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final index = widget.index;
    final card = viewModel.cardAt(index);
    if (card == null) return const SizedBox.shrink();
    return SearchResult(
      surahName: card.surahName,
      ayahNumber: card.ayah.ayah,
      ayahText: card.text,
      matches: card.matches,
      clamp: true,
      expanded: viewModel.isWhole(index),
      onExpand: () => viewModel.showWhole(index),
      onContext: () => context.push(Routes.contextSheet(card.ayah)),
      onOpen: () => context.go(Routes.mushafRead(card.ayah)),
    );
  }
}
