import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/bookmarks_metrics.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/tag_picker.dart';
import 'package:holyquran/ui/features/bookmarks/view_models/bookmarks_view_model.dart';

/// The sheet that changes the category and the tags of one bookmark from the
/// list (D-128, 8): a bookmark made in two taps takes the last category used,
/// and this is where the user changes it. It takes the copy sheet's frame.
/// A change is stored as it is made; a bookmark always has a category, so
/// pressing the chosen one does nothing.
class BookmarkTagsSheet extends StatefulWidget {
  const BookmarkTagsSheet({
    required this.viewModel,
    required this.entry,
    super.key,
  });

  final BookmarksViewModel viewModel;
  final AnnotationEntry entry;

  @override
  State<BookmarkTagsSheet> createState() => _BookmarkTagsSheetState();
}

class _BookmarkTagsSheetState extends State<BookmarkTagsSheet> {
  final _newTag = TextEditingController();
  late String? _categoryId = widget.entry.categoryId;
  late Set<String> _tagIds = widget.entry.tagIds;

  BookmarksViewModel get _viewModel => widget.viewModel;

  @override
  void dispose() {
    _newTag.dispose();
    super.dispose();
  }

  void _setCategory(String? id) {
    if (id == null) return;
    setState(() => _categoryId = id);
    _viewModel.setCategory(widget.entry.id, id);
  }

  void _setTags(Set<String> tagIds) {
    setState(() => _tagIds = tagIds);
    _viewModel.setTags(widget.entry.id, tagIds);
  }

  void _toggleTag(String id) => _setTags(
    _tagIds.contains(id) ? ({..._tagIds}..remove(id)) : {..._tagIds, id},
  );

  Future<void> _addTag() async {
    final name = _newTag.text;
    if (name.isEmpty) return;
    final id = await _viewModel.createTag(name);
    if (id == null || !mounted) return;
    _newTag.clear();
    _setTags({..._tagIds, id});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: BookmarksMetrics.keyboardInset(context),
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => CopySheetFrame(
          children: [
            CopySheetTitle(l10n.ayahRowBookmark),
            if (_viewModel.writeFailed)
              Semantics(
                container: true,
                liveRegion: true,
                child: IntegrityAlert(title: l10n.changeNotSaved),
              ),
            TagPicker(
              categories: _viewModel.categories,
              selectedCategoryId: _categoryId,
              onCategoryChanged: _setCategory,
              tags: _viewModel.tags,
              selectedTagIds: _tagIds,
              onTagToggled: _toggleTag,
              newTagController: _newTag,
              onTagAdded: _addTag,
            ),
          ],
        ),
      ),
    );
  }
}
