import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/note_location.dart';
import 'package:holyquran/routing/routes/sheet_page.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/bookmarks_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/annotation_card.dart';
import 'package:holyquran/ui/core/widgets/category_tag.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/search_field.dart';
import 'package:holyquran/ui/core/widgets/search_summary.dart';
import 'package:holyquran/ui/core/widgets/undo_bar.dart';
import 'package:holyquran/ui/features/bookmarks/view_models/bookmarks_view_model.dart';
import 'package:holyquran/ui/features/bookmarks/views/bookmark_tags_sheet.dart';

/// «العلامات والملاحظات» (`UD-01` to `UD-04`, `UD-07`, `SR-08`), an extension
/// that follows the list screen of the Search board: a back button and the
/// title, then the two lists as a switch, the search field, the filter by
/// category and tag, the summary with the order, and the cards. A card opens
/// the reader at its ayah, or the context sheet; deleting one offers «تراجع».
///
/// A null [viewModel] means the app provides no user data yet; the screen
/// then shows its title alone.
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({required this.viewModel, super.key});

  final BookmarksViewModel? viewModel;

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.viewModel?.holdUndo = MediaQuery.accessibleNavigationOf(context);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final viewModel = widget.viewModel;
    return ColoredBox(
      color: colors.ground,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: BookmarksMetrics.header,
              child: Row(
                spacing: BookmarksMetrics.headerGap,
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
                        l10n.bookmarksAndNotes,
                        style: BookmarksMetrics.titleStyle.copyWith(
                          color: colors.ink,
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
                  builder: (context, _) =>
                      _Body(viewModel: viewModel, search: _search),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.viewModel, required this.search});

  final BookmarksViewModel viewModel;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = viewModel.entries;
    final bookmarks = viewModel.tab == AnnotationTab.bookmarks;
    final alerts = viewModel.failed || viewModel.writeFailed;
    final sentence = viewModel.loaded && !viewModel.failed && entries.isEmpty
        ? viewModel.narrowed
              ? l10n.noSearchResults
              : bookmarks
              ? l10n.noBookmarksYet
              : l10n.noNotesYet
        : null;
    final prefix = <Widget>[
      Padding(
        padding: BookmarksMetrics.controls,
        child: _Controls(viewModel: viewModel, search: search),
      ),
      if (alerts)
        Padding(
          padding: BookmarksMetrics.item,
          child: Semantics(
            container: true,
            liveRegion: true,
            child: IntegrityAlert(title: l10n.changeNotSaved),
          ),
        ),
      if (sentence != null)
        Padding(
          padding: BookmarksMetrics.sentence,
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Text(
              sentence,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: context.colors.inkMuted,
              ),
            ),
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            padding: BookmarksMetrics.listEnd,
            itemCount: prefix.length + entries.length,
            itemBuilder: (context, index) => index < prefix.length
                ? prefix[index]
                : Padding(
                    padding: BookmarksMetrics.item,
                    child: _Card(
                      viewModel: viewModel,
                      entry: entries[index - prefix.length],
                    ),
                  ),
          ),
        ),
        if (viewModel.canUndo)
          Padding(
            padding: BookmarksMetrics.undoBar,
            child: UndoBar(message: l10n.itemDeleted, onUndo: viewModel.undo),
          ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.viewModel, required this.search});

  final BookmarksViewModel viewModel;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bookmarks = viewModel.tab == AnnotationTab.bookmarks;
    final mushaf = viewModel.order == ListOrder.mushaf;
    final count = viewModel.entries.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: BookmarksMetrics.controlsGap,
      children: [
        LevelSwitch(
          options: [l10n.bookmarksTabBookmarks, l10n.bookmarksTabNotes],
          selectedIndex: viewModel.tab.index,
          onChanged: (index) =>
              viewModel.selectTab(AnnotationTab.values[index]),
          semanticLabel: l10n.bookmarksAndNotes,
        ),
        SearchField(
          controller: search,
          hint: l10n.bookmarksSearchHint,
          onChanged: viewModel.search,
          onSubmitted: viewModel.search,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterGroup(
              label: l10n.categoryLabel,
              children: [
                for (final category in viewModel.categories)
                  CategoryTag(
                    category: category.builtin,
                    selected: viewModel.categoryId == category.id,
                    onPressed: () => viewModel.toggleCategory(category.id),
                  ),
              ],
            ),
            _FilterGroup(
              label: l10n.tagsLabel,
              children: [
                for (final tag in viewModel.tags)
                  FreeTag(
                    name: tag.name,
                    selected: viewModel.tagId == tag.id,
                    onPressed: () => viewModel.toggleTag(tag.id),
                  ),
              ],
            ),
          ],
        ),
        SearchSummary(
          title: bookmarks
              ? l10n.bookmarksTabBookmarks
              : l10n.bookmarksTabNotes,
          count: bookmarks
              ? l10n.bookmarksCount(count, arabicDigits(count))
              : l10n.notesCount(count, arabicDigits(count)),
          announceCount: true,
          sortLabel: mushaf ? l10n.searchSortMushafOrder : l10n.sortNewest,
          onSort: () => viewModel.selectOrder(
            mushaf ? ListOrder.newest : ListOrder.mushaf,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.viewModel, required this.entry});

  final BookmarksViewModel viewModel;
  final AnnotationEntry entry;

  void _edit(BuildContext context) {
    if (viewModel.tab == AnnotationTab.notes) {
      context.push(noteSheetLocation(entry.address, noteId: entry.id));
      return;
    }
    // A sheet over the tab bar, on the root navigator, like the routed ones.
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.push(
      SheetPage<void>(
        child: BookmarkTagsSheet(viewModel: viewModel, entry: entry),
      ).createRoute(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notes = viewModel.tab == AnnotationTab.notes;
    // The reader and the context sheet need the pack to serve this ayah.
    final inPack = entry.ayahText != null && entry.surahName != null;
    final category = viewModel.categoryOf(entry.categoryId);
    return AnnotationCard(
      surahNumber: entry.address.surah,
      ayahNumber: entry.address.ayah,
      surahName: entry.surahName,
      ayahText: entry.ayahText,
      note: entry.note,
      tags: [
        if (category != null)
          CategoryTag(
            category: category,
            selected: false,
            onPressed: () => _edit(context),
            hint: l10n.tagsEditHint,
          ),
        for (final id in entry.tagIds)
          if (viewModel.tagName(id) case final name?)
            FreeTag(
              name: name,
              selected: false,
              onPressed: () => _edit(context),
              hint: l10n.tagsEditHint,
            ),
      ],
      deleteLabel: notes ? l10n.noteDelete : l10n.bookmarkDelete,
      onDelete: () => viewModel.delete(entry),
      expanded: viewModel.isExpanded(entry.id),
      onExpand: () => viewModel.expand(entry.id),
      onEdit: notes ? () => _edit(context) : null,
      onContext: inPack
          ? () => context.push(Routes.contextSheet(entry.address))
          : null,
      onOpen: inPack
          ? () => context.push(Routes.mushafRead(entry.address))
          : null,
    );
  }
}

/// A group of filter tags under a name for a screen reader, which the tags
/// alone do not give. An empty group is left out.
class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => children.isEmpty
      ? const SizedBox.shrink()
      : Semantics(
          container: true,
          explicitChildNodes: true,
          label: label,
          child: Wrap(
            spacing: AppSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        );
}
