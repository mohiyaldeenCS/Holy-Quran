import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/category_tag.dart';
import 'package:holyquran/ui/core/widgets/text_box.dart';

/// The category and the tags of a bookmark or a note, chosen by pressing
/// their `Tag`s (`UD-01`, `UD-02`), with the field that makes a new tag. The
/// identity draws no picker; PRD §7.7 builds the note editor from `Tag` and
/// `Button`, and its gaps are `.qk-sheet`'s `space-4`.
///
/// Pressing the chosen category again reports null, which clears it. A group
/// with nothing to show is left out.
class TagPicker extends StatelessWidget {
  const TagPicker({
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.tags,
    required this.selectedTagIds,
    required this.onTagToggled,
    required this.newTagController,
    required this.onTagAdded,
    super.key,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;

  final List<UserTag> tags;
  final Set<String> selectedTagIds;
  final ValueChanged<String> onTagToggled;

  /// The name of a tag to make, and the press that makes it.
  final TextEditingController newTagController;
  final VoidCallback onTagAdded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space4,
      children: [
        if (categories.isNotEmpty)
          _Group(
            label: l10n.categoryLabel,
            children: [
              for (final category in categories)
                CategoryTag(
                  category: category.builtin,
                  selected: category.id == selectedCategoryId,
                  onPressed: () => onCategoryChanged(
                    category.id == selectedCategoryId ? null : category.id,
                  ),
                ),
            ],
          ),
        _Group(
          label: l10n.tagsLabel,
          footer: Row(
            spacing: AppSpacing.space2,
            children: [
              Expanded(
                child: TextBox(
                  controller: newTagController,
                  hint: l10n.tagNewHint,
                  onSubmitted: onTagAdded,
                ),
              ),
              Button(
                label: l10n.tagAdd,
                variant: ButtonVariant.tonal,
                onPressed: onTagAdded,
              ),
            ],
          ),
          children: [
            for (final tag in tags)
              FreeTag(
                name: tag.name,
                selected: selectedTagIds.contains(tag.id),
                onPressed: () => onTagToggled(tag.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// A group of tags under its name, with the [footer] under them.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children, this.footer});

  final String label;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.space1,
        children: [
          ExcludeSemantics(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: context.colors.inkMuted,
              ),
            ),
          ),
          if (children.isNotEmpty)
            Wrap(
              spacing: AppSpacing.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: children,
            ),
          ?footer,
        ],
      ),
    );
  }
}
