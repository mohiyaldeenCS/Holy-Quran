import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/bookmarks_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/note_editor.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/core/widgets/undo_bar.dart';
import 'package:holyquran/ui/features/bookmarks/view_models/note_sheet_view_model.dart';

/// The note sheet of an ayah (`UD-02`, `UD-04`, `UD-07`): the notes it has,
/// the editor for one of them or a new one, and the undo of a deletion. The
/// identity does not draw it; it takes the copy sheet's frame. Saving a note
/// closes the sheet.
class NoteSheetView extends StatefulWidget {
  const NoteSheetView({required this.viewModel, super.key});

  final NoteSheetViewModel viewModel;

  @override
  State<NoteSheetView> createState() => _NoteSheetViewState();
}

class _NoteSheetViewState extends State<NoteSheetView> {
  final _body = TextEditingController();
  final _newTag = TextEditingController();
  int _revision = 0;

  NoteSheetViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _revision = _viewModel.bodyRevision;
    _body
      ..text = _viewModel.body
      ..addListener(() => _viewModel.setBody(_body.text));
    _viewModel.addListener(_copyBody);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_copyBody);
    _body.dispose();
    _newTag.dispose();
    super.dispose();
  }

  // The model replaces the text when another note is chosen or deleted.
  void _copyBody() {
    if (_viewModel.bodyRevision == _revision) return;
    _revision = _viewModel.bodyRevision;
    _body.text = _viewModel.body;
  }

  Future<void> _save() async {
    if (await _viewModel.save() && mounted) GoRouter.of(context).pop();
  }

  Future<void> _addTag() async {
    final name = _newTag.text;
    await _viewModel.addTag(name);
    if (mounted && !_viewModel.writeFailed) _newTag.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    return Padding(
      padding: BookmarksMetrics.keyboardInset(context),
      child: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final surahName = _viewModel.surahName;
          final notes = _viewModel.notes;
          final editing = _viewModel.editing;
          final selected = editing == null
              ? null
              : notes.indexWhere((note) => note.id == editing.id);
          return CopySheetFrame(
            children: [
              CopySheetTitle(l10n.noteLabel),
              if (surahName != null)
                SurahName(
                  surahName,
                  format: SurahNameFormat.titledWithAyah,
                  ayah: _viewModel.address.ayah,
                  style: AppTextStyles.secondary.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
              if (_viewModel.writeFailed)
                IntegrityAlert(title: l10n.userDataNotSaved),
              NoteEditor(
                controller: _body,
                existing: [for (final note in notes) note.body],
                selectedExisting: selected,
                onExistingSelected: (index) => _viewModel.select(notes[index]),
                onNew: _viewModel.startNew,
                categories: _viewModel.categories,
                selectedCategoryId: _viewModel.categoryId,
                onCategoryChanged: _viewModel.setCategory,
                tags: _viewModel.tags,
                selectedTagIds: _viewModel.tagIds,
                onTagToggled: _viewModel.toggleTag,
                newTagController: _newTag,
                onTagAdded: _addTag,
                onSave: _viewModel.canSave ? _save : null,
                onDelete: editing == null ? null : _viewModel.delete,
              ),
              if (_viewModel.canUndo)
                UndoBar(message: l10n.itemDeleted, onUndo: _viewModel.undo),
            ],
          );
        },
      ),
    );
  }
}
