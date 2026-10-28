import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/index_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/surah_list_item.dart';
import 'package:holyquran/ui/features/index/view_models/index_view_model.dart';
import 'package:holyquran/ui/features/index/views/division_row.dart';

/// The index (`NV-01`, `NV-02`) as the Screens2 board draws it: the title with
/// its summary, the three tabs, and the rows of the tab chosen. Each row opens
/// the reader at its first ayah. [viewModel] is null while the app has no base
/// pack, and then only the title is shown.
class IndexScreen extends StatelessWidget {
  const IndexScreen({required this.viewModel, super.key});

  final IndexViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final viewModel = this.viewModel;
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      bottom: false,
      child: viewModel == null
          ? _Header(title: l10n.indexTitle)
          : ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    title: l10n.indexTitle,
                    summary: viewModel.hasData
                        ? l10n.indexSummary(
                            arabicDigits(viewModel.surahCount),
                            arabicDigits(viewModel.juzCount),
                          )
                        : null,
                    goTo: viewModel.hasData ? const _GoTo() : null,
                    tabs: viewModel.hasData ? _Tabs(viewModel) : null,
                  ),
                  if (viewModel.hasData)
                    Expanded(
                      child: _Rows(viewModel, key: ValueKey(viewModel.tab)),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.summary, this.goTo, this.tabs});

  final String title;
  final String? summary;
  final Widget? goTo;
  final Widget? tabs;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final summary = this.summary;
    return Padding(
      padding: IndexMetrics.header,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: IndexMetrics.headerGap,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: AppSpacing.space3,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppTextStyles.screenTitle.copyWith(color: colors.ink),
                ),
              ),
              // The summary wraps rather than push the title out at large text.
              if (summary != null)
                Flexible(
                  child: Text(
                    summary,
                    textAlign: TextAlign.end,
                    style: IndexMetrics.summaryStyle.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
          ?goTo,
          ?tabs,
        ],
      ),
    );
  }
}

/// The way to «اذهب إلى» (D-140, 11), in the slot the board keeps between the
/// title row and the tabs for its search field.
class _GoTo extends StatelessWidget {
  const _GoTo();

  @override
  Widget build(BuildContext context) => Button(
    label: AppLocalizations.of(context).goToTitle,
    variant: ButtonVariant.tonal,
    onPressed: () => context.push(Routes.goToSheet),
  );
}

class _Tabs extends StatelessWidget {
  const _Tabs(this.viewModel);

  final IndexViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LevelSwitch(
      options: [l10n.indexTabSurahs, l10n.indexTabJuz, l10n.indexTabHizb],
      selectedIndex: viewModel.tab.index,
      onChanged: (index) => viewModel.selectTab(IndexTab.values[index]),
      semanticLabel: l10n.indexTitle,
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows(this.viewModel, {super.key});

  final IndexViewModel viewModel;

  void _open(BuildContext context, QuranAddress address) =>
      context.push(Routes.mushafRead(address));

  @override
  Widget build(BuildContext context) {
    final rows = switch (viewModel.tab) {
      IndexTab.surahs => [
        for (final row in viewModel.surahRows)
          SurahListItem(
            number: row.info.number,
            name: row.info.name,
            ayahCount: row.info.ayahCount,
            revelation: row.info.revelationPlace,
            page: row.page,
            lastRead: row.lastRead,
            onPressed: () => _open(context, row.address),
          ),
      ],
      IndexTab.juz || IndexTab.hizb => [
        for (final row
            in viewModel.tab == IndexTab.juz
                ? viewModel.juzRows
                : viewModel.hizbRows)
          DivisionRow(row: row, onPressed: () => _open(context, row.address)),
      ],
    };
    return ListView.builder(
      padding: IndexMetrics.list.copyWith(bottom: IndexMetrics.listEnd),
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }
}
