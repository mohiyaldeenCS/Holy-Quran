import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/small_button.dart';

// The selection frame is the thin line of `.qk-hl-select`, `inset 0 0 0
// 1.5px var(--selection-line)`; the toolbar takes the same fill and frame as
// the ayah it belongs to (PRD §7.7: built from `IconButton` and `selection`).
const double _frame = 1.5;

/// The toolbar of the selected ayah (PRD §7.4, §7.7): play, bookmark, study,
/// copy and share, each an [IconButton] named by a word. An action whose
/// callback is null is left out, since its sheet cannot open yet or here. A
/// [bookmarked] ayah shows the bookmark as the solid button and says so to a
/// screen reader, so the state is not told by colour alone. [onUndo], while
/// given, adds the undo word after a bookmark was removed (`UD-07`). A
/// [notice] is said in words above the toolbar, and announced to a screen
/// reader as it appears.
final class AyahToolbar extends StatelessWidget {
  const AyahToolbar({
    this.onPlay,
    this.onBookmark,
    this.bookmarked = false,
    this.onStudy,
    this.onCopy,
    this.onShare,
    this.onUndo,
    this.notice,
    super.key,
  });

  final VoidCallback? onPlay;
  final VoidCallback? onBookmark;
  final bool bookmarked;
  final VoidCallback? onStudy;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final VoidCallback? onUndo;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final toolbar = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.selection,
        border: Border.all(color: colors.selectionLine, width: _frame),
        borderRadius: BorderRadius.circular(AppRadius.radiusFull),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onPlay case final onPlay?)
              IconButton(
                icon: IconName.play,
                label: l10n.playerPlay,
                onPressed: onPlay,
              ),
            if (onBookmark case final onBookmark?)
              MergeSemantics(
                child: Semantics(
                  selected: bookmarked,
                  child: IconButton(
                    icon: IconName.bookmark,
                    label: l10n.toolbarBookmark,
                    onPressed: onBookmark,
                    tone: bookmarked
                        ? IconButtonTone.solid
                        : IconButtonTone.plain,
                  ),
                ),
              ),
            if (onStudy case final onStudy?)
              IconButton(
                icon: IconName.study,
                label: l10n.toolbarStudy,
                onPressed: onStudy,
              ),
            if (onCopy case final onCopy?)
              IconButton(
                icon: IconName.copy,
                label: l10n.toolbarCopy,
                onPressed: onCopy,
              ),
            if (onShare case final onShare?)
              IconButton(
                icon: IconName.share,
                label: l10n.toolbarShare,
                onPressed: onShare,
              ),
            if (onUndo case final onUndo?)
              SmallButton(label: l10n.undo, onPressed: onUndo, outlined: true),
          ],
        ),
      ),
    );
    final notice = this.notice;
    if (notice == null) return toolbar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.space2,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.error),
            borderRadius: BorderRadius.circular(AppRadius.radiusFull),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space2,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                notice,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: colors.error),
              ),
            ),
          ),
        ),
        toolbar,
      ],
    );
  }
}
