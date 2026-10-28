import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

// The list of bookmarks and notes is not drawn. Its item follows a result of
// the Search board (Search.dc.html, the list of «البحث»): the reference line
// with its round buttons over the ayah's card, set 4 apart.

// Search.dc.html, the result's reference: `font-size:15px;font-weight:600`
// in `#0E5A52` (`primary`); no line height, so the font's own (CSS `normal`),
// and the style does not inherit.
const TextStyle _referenceStyle = TextStyle(
  inherit: false,
  fontFamily: AppFonts.sans,
  fontSize: 15,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
  leadingDistribution: TextLeadingDistribution.even,
);
// Search.dc.html, the result's buttons: `<svg width="22" …>` in a 48 button,
// `gap:2px` between them.
const double _actionIconSize = 22;
const double _actionsGap = 2;

// .qk-sheet-rows: border-radius 20px.
const BorderRadius _noteRadius = BorderRadius.all(Radius.circular(20));

// The screen reader's order (AX-01): the reference, the ayah, the note, the
// tags, then the actions.
const double _referenceOrder = 0;
const double _ayahOrder = 1;
const double _noteOrder = 2;
const double _tagsOrder = 3;
const double _actionsOrder = 4;

/// One bookmark or note in its list (`UD-03`, `RD-14`): the surah and ayah
/// over the round buttons, the ayah as an [AyahRow] card, the note under it
/// when there is one, and the category and tags as `Tag`s.
///
/// Each part is left out when its data is: no [surahName] and no [ayahText]
/// when the app has no base pack, no [note] on a bookmark, no [tags] on an
/// ayah that has none. A button whose callback is null is not shown.
class AnnotationCard extends StatelessWidget {
  const AnnotationCard({
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
    super.key,
  });

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final surahName = this.surahName;
    final ayahText = this.ayahText;
    final note = this.note;
    final onContext = this.onContext;
    final onOpen = this.onOpen;
    final onEdit = this.onEdit;
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
                child: surahName == null
                    ? const SizedBox.shrink()
                    : Semantics(
                        container: true,
                        sortKey: const OrdinalSortKey(_referenceOrder),
                        child: SurahName(
                          surahName,
                          format: SurahNameFormat.withAyah,
                          ayah: ayahNumber,
                          style: _referenceStyle.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ),
              ),
              Semantics(
                container: true,
                sortKey: const OrdinalSortKey(_actionsOrder),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: _actionsGap,
                  children: [
                    if (onEdit != null)
                      IconButton(
                        icon: IconName.note,
                        label: l10n.noteLabel,
                        iconSize: _actionIconSize,
                        onPressed: onEdit,
                      ),
                    if (onContext != null)
                      IconButton(
                        icon: IconName.context,
                        label: l10n.searchResultContext,
                        iconSize: _actionIconSize,
                        onPressed: onContext,
                      ),
                    if (onOpen != null)
                      IconButton(
                        icon: IconName.mushaf,
                        label: l10n.searchResultOpen,
                        iconSize: _actionIconSize,
                        onPressed: onOpen,
                      ),
                    IconButton(
                      icon: IconName.delete,
                      label: deleteLabel,
                      iconSize: _actionIconSize,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ayahText != null)
            Semantics(
              container: true,
              sortKey: const OrdinalSortKey(_ayahOrder),
              child: AyahRow(number: ayahNumber, text: ayahText),
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
