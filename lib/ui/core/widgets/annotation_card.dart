import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/search_result.dart';

// The list of bookmarks and notes is not drawn. Its item is a result of the
// Search board (Search.dc.html, the list of «البحث»), which `SearchResult`
// builds: the reference over the round buttons, and the ayah at the compact
// size, cut where it is long. The delete and edit buttons, the note and the
// tags are added to that card.

// .qk-sheet-rows: border-radius 20px.
const BorderRadius _noteRadius = BorderRadius.all(Radius.circular(20));

// The screen reader's order (AX-01) in the card drawn without a pack: the
// reference, the note, the tags, then the buttons.
const double _referenceOrder = 0;
const double _noteOrder = 1;
const double _tagsOrder = 2;
const double _actionsOrder = 3;

/// One bookmark or note in its list (`UD-03`, `RD-14`): a [SearchResult] card
/// with the ayah in the compact size, cut where it is long and shown whole by
/// «المزيد», to which a delete button, the note and the category and tags as
/// `Tag`s are added.
///
/// The card needs the base pack for the ayah and the surah's name. Without
/// them ([surahName], [ayahText], [onContext] or [onOpen] null) it shows the
/// surah and ayah numbers, which are the user's own address, where the name
/// would be, and no ayah. Whatever else has no data is left out: no [note] on
/// a bookmark, no [tags] on an ayah that has none, no [onEdit] on a bookmark.
class AnnotationCard extends StatelessWidget {
  const AnnotationCard({
    required this.surahNumber,
    required this.ayahNumber,
    required this.deleteLabel,
    required this.onDelete,
    this.surahName,
    this.ayahText,
    this.note,
    this.tags = const [],
    this.onContext,
    this.onOpen,
    this.onEdit,
    this.expanded = false,
    this.onExpand,
    super.key,
  });

  final int surahNumber;
  final int ayahNumber;
  final PackText? surahName;
  final PackText? ayahText;

  /// The user's note, shown whole.
  final String? note;

  /// The category and tags, as `Tag`s the caller builds.
  final List<Widget> tags;

  final String deleteLabel;
  final VoidCallback onDelete;
  final VoidCallback? onContext;
  final VoidCallback? onOpen;

  /// Opens the note's editor; given for a note.
  final VoidCallback? onEdit;

  /// Whether a long ayah is shown whole, and the press that shows it. The
  /// caller keeps it, as `SearchResult` asks, so a card scrolled away and
  /// built again remembers. Without [onExpand] a long ayah is shown whole.
  final bool expanded;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final surahName = this.surahName;
    final ayahText = this.ayahText;
    final onContext = this.onContext;
    final onOpen = this.onOpen;
    final onEdit = this.onEdit;
    final note = this.note;
    final buttons = [
      if (onEdit != null)
        IconButton(
          icon: IconName.note,
          label: l10n.noteLabel,
          iconSize: SearchResult.actionIconSize,
          onPressed: onEdit,
        ),
      IconButton(
        icon: IconName.delete,
        label: deleteLabel,
        iconSize: SearchResult.actionIconSize,
        onPressed: onDelete,
      ),
    ];
    final footer = note == null && tags.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.space2,
            children: [
              if (note != null) _Note(note),
              if (tags.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: tags,
                ),
            ],
          );
    if (surahName != null &&
        ayahText != null &&
        onContext != null &&
        onOpen != null) {
      return SearchResult(
        surahName: surahName,
        ayahNumber: ayahNumber,
        ayahText: ayahText,
        onContext: onContext,
        onOpen: onOpen,
        clamp: onExpand != null,
        expanded: expanded,
        onExpand: onExpand,
        actions: buttons,
        footer: footer,
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.space1,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  sortKey: const OrdinalSortKey(_referenceOrder),
                  child: Text(
                    l10n.surahTitleAyahReference(
                      arabicDigits(surahNumber),
                      arabicDigits(ayahNumber),
                    ),
                    style: SearchResult.referenceStyle.copyWith(
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ),
              Semantics(
                container: true,
                sortKey: const OrdinalSortKey(_actionsOrder),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: SearchResult.actionsGap,
                  children: buttons,
                ),
              ),
            ],
          ),
          if (note != null)
            Semantics(
              container: true,
              sortKey: const OrdinalSortKey(_noteOrder),
              child: _Note(note),
            ),
          if (tags.isNotEmpty)
            Semantics(
              container: true,
              sortKey: const OrdinalSortKey(_tagsOrder),
              child: Wrap(
                spacing: AppSpacing.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: tags,
              ),
            ),
        ],
      ),
    );
  }
}

/// The note, in the box of `.qk-sheet-rows` (`surface-sunk`, a `line` border,
/// radius 20) under the ayah's card.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceSunk,
        border: Border.all(color: colors.line),
        borderRadius: _noteRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
        child: Text(
          text,
          style: AppTextStyles.body.copyWith(color: colors.ink),
        ),
      ),
    );
  }
}
