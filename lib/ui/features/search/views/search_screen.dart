import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/metrics/search_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/mode_chips.dart';
import 'package:holyquran/ui/core/widgets/number_field.dart';
import 'package:holyquran/ui/core/widgets/place_refusal.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';
import 'package:holyquran/ui/features/search/view_models/search_view_model.dart';
import 'package:holyquran/ui/features/search/views/pinned_controls.dart';
import 'package:holyquran/ui/features/search/views/search_history.dart';
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
    // Pushed over the results, so that Back returns to them.
    if (target != null && mounted) {
      unawaited(context.push<void>(Routes.mushafRead(target.start)));
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
                builder: (context, _) => _body(viewModel),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(SearchViewModel viewModel) {
    final l10n = AppLocalizations.of(context);
    // A pack that fails its check shows no text, not even in a result
    // (PRD §9.5), whether it failed before the screen opened or after.
    if (!viewModel.hasData) {
      return Padding(
        padding: SearchMetrics.controls,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: IntegrityAlert(
            title: l10n.integrityBaseTitle,
            body: l10n.integrityBaseBody,
          ),
        ),
      );
    }
    // Which chips there are is not known until the pack has answered, which
    // the first index build can make slow: the field waits, disabled.
    if (!viewModel.loaded) {
      return Padding(
        padding: SearchMetrics.controls,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: SearchField(
            controller: _field,
            enabled: false,
            onChanged: viewModel.edit,
            onSubmitted: (_) {},
          ),
        ),
      );
    }
    // The pack has no search form this screen knows, so nothing can be
    // searched and there is nothing to show: a field with no data is not
    // shown (docs/DESIGN_SYSTEM.md, "When data is missing").
    if (!viewModel.canSearch) return const SizedBox.shrink();
    return PinnedControls(
      controls: _Controls(
        viewModel: viewModel,
        field: _field,
        scope: _scope,
        onSubmitted: (text) => _submit(viewModel, text),
      ),
      results: _results(viewModel),
    );
  }

  List<Widget> _results(SearchViewModel viewModel) {
    if (viewModel.typed.trim().isEmpty) {
      return [
        if (viewModel.history.isNotEmpty)
          SearchHistorySliver(
            queries: viewModel.history,
            onChoose: (query) => _choose(viewModel, query),
            onClear: viewModel.canClearHistory ? viewModel.clearHistory : null,
            clearFailed: viewModel.historyClearFailed,
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
          NumberField(
            controller: scope,
            label: choice == ScopeChoice.surah
                ? l10n.searchScopeSurahNumber
                : l10n.searchScopeJuzNumber,
            onChanged: viewModel.setScopeText,
          ),
        if (refusal != null)
          PlaceRefusal(error: refusal, surahName: viewModel.surahName),
        if (viewModel.typed.trim().isNotEmpty &&
            (viewModel.searched || viewModel.failed))
          SearchSummaryLine(viewModel: viewModel),
      ],
    );
  }
}
