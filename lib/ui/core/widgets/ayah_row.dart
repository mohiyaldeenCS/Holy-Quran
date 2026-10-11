import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

// .qk-ayah-row: border-radius 20px.
const BorderRadius _radius = BorderRadius.all(Radius.circular(20));
// .qk-ayah-row: gap 2px, between the top row and the text.
const double _gap = 2;
// AyahRow in index.jsx: <AyahMarker size={36} />.
const double _markerSize = 36;
// .qk-ayah-row .qk-ayah-no: border-width 1.5px.
const double _markerRingWidth = 1.5;

// The screen reader's order (AX-01): the ayah, its number, the actions.
const double _textOrder = 0;
const double _markerOrder = 1;
const double _actionsOrder = 2;

/// One ayah as a card (`AyahRow`, `.qk-ayah-row`), for lists, search results
/// and bookmarks: its marker, then the actions play from here, bookmark and
/// study, then [text] at the ayah size.
///
/// A screen reader takes the ayah first, then «الآية n», then the actions
/// (AX-01), whatever the drawn order.
///
/// [text] is exactly one ayah, with no marker inside it. An action whose
/// callback is null is not shown.
class AyahRow extends StatelessWidget {
  const AyahRow({
    required this.number,
    required this.text,
    this.onPlay,
    this.onBookmark,
    this.onStudy,
    super.key,
  });

  final int number;
  final PackText text;
  final VoidCallback? onPlay;
  final VoidCallback? onBookmark;
  final VoidCallback? onStudy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final actions = [
      (IconName.play, l10n.ayahRowPlayFromHere, onPlay),
      (IconName.bookmark, l10n.ayahRowBookmark, onBookmark),
      (IconName.study, l10n.ayahRowStudy, onStudy),
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      // Container adds the 1px border to the padding, as CSS does.
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.line),
          borderRadius: _radius,
        ),
        // .qk-ayah-row: padding var(--space-2) var(--space-5) var(--space-3).
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space5,
          AppSpacing.space2,
          AppSpacing.space5,
          AppSpacing.space3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: _gap,
          children: [
            // .qk-ayah-row-top: centred across, the marker and the actions at
            // either end.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(
                  container: true,
                  sortKey: const OrdinalSortKey(_markerOrder),
                  child: AyahMarker(
                    number: number,
                    size: _markerSize,
                    ringWidth: _markerRingWidth,
                  ),
                ),
                Semantics(
                  container: true,
                  sortKey: const OrdinalSortKey(_actionsOrder),
                  // .qk-ayah-row-actions: gap var(--space-1).
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.space1,
                    children: [
                      for (final (icon, label, onPressed) in actions)
                        if (onPressed != null)
                          IconButton(
                            icon: icon,
                            label: label,
                            onPressed: onPressed,
                          ),
                    ],
                  ),
                ),
              ],
            ),
            Semantics(
              container: true,
              sortKey: const OrdinalSortKey(_textOrder),
              child: QuranText(
                text,
                size: QuranTextSize.ayah,
                align: QuranTextAlign.start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
