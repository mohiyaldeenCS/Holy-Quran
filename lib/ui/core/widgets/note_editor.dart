import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/tag_picker.dart';
import 'package:holyquran/ui/core/widgets/text_box.dart';

/// The note editor of PRD §7.7 (`UD-02`, `UD-04`): the notes already on the
/// ayah, the note's text, its category and tags, and the actions to save or
/// delete it. It is the body of a sheet; the sheet's frame and title are the
/// caller's. The identity draws it no further than «نص، تصنيف، وسوم» from
/// `Tag` and `Button`: the text is a [TextBox], the category and tags a
/// [TagPicker], the gaps `.qk-sheet`'s `space-4`.
class NoteEditor extends StatelessWidget {
  const NoteEditor({
    required this.controller,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.tags,
    required this.selectedTagIds,
    required this.onTagToggled,
    required this.newTagController,
    required this.onTagAdded,
    required this.onSave,
    this.onDelete,
    this.existing = const [],
    this.selectedExisting,
    this.onExistingSelected,
    this.onNew,
    super.key,
  });

  /// The note's text.
  final TextEditingController controller;

  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;

  final List<UserTag> tags;
  final Set<String> selectedTagIds;
  final ValueChanged<String> onTagToggled;
  final TextEditingController newTagController;
  final VoidCallback onTagAdded;

  /// Null while the note cannot be saved, as when its text is empty.
  final VoidCallback? onSave;

  /// Shown when the note in the editor is saved already.
  final VoidCallback? onDelete;

  /// The texts of the notes the ayah has, older first, and which of them the
  /// editor holds; null when it holds a new one.
  final List<String> existing;
  final int? selectedExisting;
  final ValueChanged<int>? onExistingSelected;

  /// Starts another note; shown while the editor holds a saved one.
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onDelete = this.onDelete;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space4,
      children: [
        if (existing.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.space2,
            children: [
              for (final (index, text) in existing.indexed)
                _ExistingNote(
                  text: text,
                  selected: index == selectedExisting,
                  onPressed: () => onExistingSelected?.call(index),
                ),
            ],
          ),
        if (onNew != null && selectedExisting != null)
          Button(
            label: l10n.noteAdd,
            variant: ButtonVariant.tonal,
            icon: IconName.plus,
            onPressed: onNew,
          ),
        TextBox(controller: controller, hint: l10n.noteHint, multiline: true),
        TagPicker(
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          onCategoryChanged: onCategoryChanged,
          tags: tags,
          selectedTagIds: selectedTagIds,
          onTagToggled: onTagToggled,
          newTagController: newTagController,
          onTagAdded: onTagAdded,
        ),
        Button(label: l10n.noteSave, onPressed: onSave),
        if (onDelete != null)
          Button(
            label: l10n.noteDelete,
            variant: ButtonVariant.outline,
            icon: IconName.delete,
            onPressed: onDelete,
          ),
      ],
    );
  }
}

/// A note the ayah has already, pressed to edit it. The one in the editor
/// fills with `primary-soft` and carries the check mark of `ModeChips`, so it
/// is not told by colour alone.
class _ExistingNote extends StatelessWidget {
  const _ExistingNote({
    required this.text,
    required this.selected,
    required this.onPressed,
  });

  final String text;
  final bool selected;
  final VoidCallback onPressed;

  static final BorderRadius _radius = BorderRadius.circular(
    AppRadius.radiusButton,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.onPrimarySoft : colors.ink;
    return Semantics(
      container: true,
      selected: selected,
      label: text,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: _radius,
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.targetMin),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space2,
            ),
            decoration: BoxDecoration(
              color: selected ? colors.primarySoft : colors.surface,
              // An undrawn side when selected, as `Tag` and `ModeChips` keep.
              border: Border.all(
                color: colors.line,
                style: selected ? BorderStyle.none : BorderStyle.solid,
              ),
              borderRadius: _radius,
            ),
            child: Row(
              spacing: AppSpacing.space2,
              children: [
                if (selected) Icon(IconName.check, color: foreground),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
