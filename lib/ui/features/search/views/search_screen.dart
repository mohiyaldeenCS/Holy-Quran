import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/metrics/search_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';
import 'package:holyquran/ui/features/search/view_models/search_view_model.dart';
import 'package:holyquran/ui/features/search/views/scope_field.dart';
import 'package:holyquran/ui/features/search/views/search_history.dart';
import 'package:holyquran/ui/features/search/views/search_refusal.dart';
import 'package:holyquran/ui/features/search/views/search_results.dart';

/// The search screen (`SR-01` to `SR-07`, `SR-10`) as the Search board draws
/// it: the back button and title, the field, the chips of the search kinds
/// the pack has data for, the summary and the result cards. The board does
/// not draw the scope, which `SR-06` asks for: it is a second group of chips
/// and a number field built from the same parts. [viewModel] is null while
/// the app has no base pack, and then only the title is shown.
class SearchScreen extends StatefulWidget {
  const SearchScreen({required this.viewModel, super.key});

  final SearchViewModel? viewModel;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _field = TextEditingController();
  final _scope = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    _scope.dispose();
    super.dispose();
  }

  Future<void> _submit(SearchViewModel viewModel, String text) async {
    final target = await viewModel.submit(text);
    if (target != null && mounted) {
      context.go(Routes.mushafRead(target.start));
    }
  }

  void _choose(SearchViewModel viewModel, String query) {
    _field.text = query;
    _submit(viewModel, query);
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.study);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewModel = widget.viewModel;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: SearchMetrics.header,
            child: Row(
              spacing: SearchMetrics.headerGap,
              children: [
                IconButton(
                  icon: IconName.previous,
                  label: l10n.back,
                  tone: IconButtonTone.tint,
                  onPressed: _back,
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.searchTitle,
                      style: SearchMetrics.titleStyle.copyWith(
                        color: context.colors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (viewModel != null)
            Expanded(
              child: ListenableBuilder(
                listenable: viewModel,
                builder: (context, _) => CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: SearchMetrics.controls,
                      sliver: SliverToBoxAdapter(
                        child: _Controls(
                          viewModel: viewModel,
                          field: _field,
                          scope: _scope,
                          onSubmitted: (text) => _submit(viewModel, text),
                        ),
                      ),
                    ),
                    ..._below(viewModel),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _below(SearchViewModel viewModel) {
    if (viewModel.typed.trim().isEmpty) {
      return [
        if (viewModel.history.isNotEmpty)
          SearchHistorySliver(
            queries: viewModel.history,
            onChoose: (query) => _choose(viewModel, query),
            onClear: viewModel.canClearHistory ? viewModel.clearHistory : null,
          ),
      ];
    }
    return [if (viewModel.searched) SearchResultsSliver(viewModel: viewModel)];
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.viewModel,
    required this.field,
    required this.scope,
    required this.onSubmitted,
  });

  final SearchViewModel viewModel;
  final TextEditingController field;
  final TextEditingController scope;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refusal = viewModel.refusal;
    final choice = viewModel.scopeChoice;
    final kindLabels = {
      SearchKinds.word: l10n.searchModeWord,
      SearchKinds.bare: l10n.searchModeBare,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: SearchMetrics.controlsGap,
      children: [
        SearchField(
          controller: field,
          onChanged: viewModel.edit,
          onSubmitted: onSubmitted,
        ),
        if (viewModel.kinds.isNotEmpty)
          ModeChips(
            label: l10n.searchModesLabel,
            options: [for (final kind in viewModel.kinds) kindLabels[kind]!],
            selectedIndex: viewModel.kindIndex,
            onChanged: viewModel.selectKind,
          ),
        ModeChips(
          label: l10n.searchScopeLabel,
          options: [l10n.searchScopeAll, l10n.goToSurah, l10n.goToJuz],
          selectedIndex: choice.index,
          onChanged: (index) {
            scope.clear();
            viewModel.selectScope(ScopeChoice.values[index]);
          },
        ),
        if (choice != ScopeChoice.whole)
          ScopeField(
            controller: scope,
            label: choice == ScopeChoice.surah ? l10n.goToSurah : l10n.goToJuz,
            onChanged: viewModel.setScopeText,
          ),
        if (refusal != null)
          SearchRefusal(error: refusal, surahName: viewModel.surahName),
        if (viewModel.searched && viewModel.typed.trim().isNotEmpty)
          SearchSummaryLine(viewModel: viewModel),
      ],
    );
  }
}
