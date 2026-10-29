import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/note_editor.dart';
import 'package:holyquran/ui/core/widgets/stepper.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';

// The note editor's samples: the four categories of Tag/README.md and two
// tags, named with the gallery's sample labels.
const List<Category> _noteCategories = [
  Category(id: 'sample-memorise', builtin: BuiltinCategory.memorise),
  Category(id: 'sample-review', builtin: BuiltinCategory.review),
  Category(id: 'sample-study', builtin: BuiltinCategory.study),
  Category(id: 'sample-important', builtin: BuiltinCategory.important),
];
const List<String> _noteTagIds = ['sample-tag-a', 'sample-tag-b'];

// Stepper/preview.html: each sample's starting value and bounds.
const int _repeatStart = 7;
const int _repeatMax = 20;
const int _mergeStart = 3;
const int _mergeMax = 10;
const int _silenceStart = 3;
const int _silenceMin = 0;
const int _silenceMax = 10;

/// The gallery's controls section: `Tag` in its four shapes, selected and
/// not, and `Stepper`, as their previews show them, and the note editor
/// (PRD §7.7), which is built from `Tag` and `Button`.
class ControlsGallery extends StatefulWidget {
  const ControlsGallery({super.key});

  @override
  State<ControlsGallery> createState() => _ControlsGalleryState();
}

class _ControlsGalleryState extends State<ControlsGallery> {
  // The tags of the first row start selected, those of the second do not.
  final Set<(int, TagShape)> _selected = {
    for (final shape in TagShape.values) (0, shape),
  };
  int _repeat = _repeatStart;
  int _merge = _mergeStart;
  int _silence = _silenceStart;

  final _noteBody = TextEditingController();
  final _newTag = TextEditingController();
  String? _noteCategory = _noteCategories.first.id;
  final Set<String> _noteTags = {_noteTagIds.first};

  @override
  void dispose() {
    _noteBody.dispose();
    _newTag.dispose();
    super.dispose();
  }

  void _toggle((int, TagShape) tag) => setState(() {
    if (!_selected.remove(tag)) _selected.add(tag);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    // Tag/README.md pairs each shape with a category. The preview's category
    // colours are not settled (O-14, D-088), so the gallery shows the shapes
    // in theme colours.
    final categories = [
      (TagShape.circle, l10n.tagMemorise, colors.primary),
      (TagShape.square, l10n.tagReview, colors.accent),
      (TagShape.diamond, l10n.tagStudy, colors.info),
      (TagShape.ring, l10n.tagImportant, colors.error),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.space6,
      children: [
        GallerySection(
          title: l10n.gallerySectionTag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.space3,
            children: [
              for (final row in [0, 1])
                galleryRow([
                  for (final (shape, label, color) in categories)
                    Tag(
                      label: label,
                      shape: shape,
                      color: color,
                      selected: _selected.contains((row, shape)),
                      onPressed: () => _toggle((row, shape)),
                    ),
                ]),
            ],
          ),
        ),
        GallerySection(
          title: l10n.noteLabel,
          child: NoteEditor(
            controller: _noteBody,
            categories: _noteCategories,
            selectedCategoryId: _noteCategory,
            onCategoryChanged: (id) => setState(() => _noteCategory = id),
            tags: [
              UserTag(
                id: _noteTagIds.first,
                name: l10n.sampleWord,
                createdAt: DateTime.utc(2026),
              ),
              UserTag(
                id: _noteTagIds.last,
                name: l10n.sampleInfo,
                createdAt: DateTime.utc(2026),
              ),
            ],
            selectedTagIds: _noteTags,
            onTagToggled: (id) => setState(() {
              if (!_noteTags.remove(id)) _noteTags.add(id);
            }),
            newTagController: _newTag,
            onTagAdded: () {},
            onSave: () {},
            onDelete: () {},
            existing: [l10n.sampleText],
            selectedExisting: 0,
            onExistingSelected: (_) {},
            onNew: () {},
          ),
        ),
        GallerySection(
          title: l10n.gallerySectionStepper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stepper(
                label: l10n.galleryStepperRepeat,
                value: _repeat,
                max: _repeatMax,
                onChanged: (value) => setState(() => _repeat = value),
              ),
              Stepper(
                label: l10n.galleryStepperMerge,
                value: _merge,
                max: _mergeMax,
                onChanged: (value) => setState(() => _merge = value),
              ),
              Stepper(
                label: l10n.galleryStepperSilence,
                value: _silence,
                min: _silenceMin,
                max: _silenceMax,
                unit: l10n.galleryStepperSeconds,
                onChanged: (value) => setState(() => _silence = value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
