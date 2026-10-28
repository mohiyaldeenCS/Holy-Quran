import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/metrics/index_metrics.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// Screen metrics of the bookmarks and notes screen and the note sheet. The
/// identity draws neither (PRD §7.6). The screen follows the list screen of
/// the Search board (`design/identity-boards/Search.dc.html`, «البحث»): a
/// back button and a title, then the controls, then the list. The sheet
/// follows the copy sheet's frame.
abstract final class BookmarksMetrics {
  // Search.dc.html, the header: `padding:24px 16px 8px`, `gap:10px`, the
  // title `font-size:22px;font-weight:700`; the resource manager keeps them.
  static const EdgeInsetsDirectional header = resourcesHeaderPadding;
  static const double headerGap = resourcesHeaderGap;
  static const TextStyle titleStyle = resourcesTitleStyle;

  // Search.dc.html, the controls under the header: `padding:0 20px;
  // display:flex;flex-direction:column;gap:12px`, the gap being `space-3`.
  // The list under them starts `padding:12px` below, the same token.
  static const EdgeInsetsDirectional controls = EdgeInsetsDirectional.fromSTEB(
    20,
    0,
    20,
    AppSpacing.space3,
  );
  static const double controlsGap = AppSpacing.space3;

  // Search.dc.html, the list: `padding:12px 20px 0;display:flex;
  // flex-direction:column;gap:10px`. Each card carries the gap below it.
  static const EdgeInsetsDirectional item = EdgeInsetsDirectional.fromSTEB(
    20,
    0,
    20,
    10,
  );

  // The board's list has no end, so the spacing token that keeps the last
  // card clear of the tab bar's shadow is chosen, as the index chooses it.
  static const EdgeInsets listEnd = EdgeInsets.only(bottom: AppSpacing.space5);

  // The empty and failed states are one calm sentence under the controls, in
  // the list's inset. The identity draws none; the padding is a spacing
  // token.
  static const EdgeInsetsDirectional sentence = EdgeInsetsDirectional.symmetric(
    horizontal: 20,
    vertical: AppSpacing.space5,
  );

  // The undo bar stands under the list in the list's inset. How long it is
  // shown is not drawn either: it lies well inside `undoWindow`
  // (lib/domain/models/bookmark.dart), the time the repositories keep a
  // deletion, so its button never outlives the undo.
  static const EdgeInsetsDirectional undoBar = EdgeInsetsDirectional.fromSTEB(
    20,
    AppSpacing.space2,
    20,
    AppSpacing.space3,
  );
  static const Duration undoShown = Duration(seconds: 8);

  // The note sheet keeps its content above the keyboard, as the go-to sheet
  // does.
  static EdgeInsets keyboardInset(BuildContext context) =>
      IndexMetrics.keyboardInset(context);
}
