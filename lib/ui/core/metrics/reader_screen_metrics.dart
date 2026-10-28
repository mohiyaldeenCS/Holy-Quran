import 'package:flutter/painting.dart';

import 'package:holyquran/ui/core/metrics/reader_metrics.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// Surah-mode reader screen metrics the boards draw that are not tokens
/// (docs/DESIGN_SYSTEM.md, "Metrics that are not tokens"). The text column's
/// sides and gaps are [ReaderMetrics]'.
abstract final class ReaderScreenMetrics {
  /// The position bar's row, `padding: 28px 24px 0` (`Screens.dc.html`, the
  /// surah-mode reader).
  static const EdgeInsetsDirectional barPadding =
      EdgeInsetsDirectional.fromSTEB(24, 28, 24, 0);

  /// The text column's top, `padding: 18px 28px 0` (`Screens.dc.html`, the
  /// surah-mode reader); its sides are [ReaderMetrics.textInset].
  static const double columnTop = 18;

  /// Below the footer page number, `padding-bottom: 10px` (`Screens.dc.html`
  /// l.87, the surah-mode reader).
  static const EdgeInsetsDirectional footerPadding = EdgeInsetsDirectional.only(
    bottom: 10,
  );

  /// A surah's header and its text, each inset by the column's sides and
  /// followed by the gap between the column's parts (`Screens.dc.html`,
  /// `gap: 22px`); the gap after the text, before the next surah's header,
  /// is a reading, as the board draws one surah.
  static const EdgeInsetsDirectional blockPadding =
      EdgeInsetsDirectional.fromSTEB(
        ReaderMetrics.textInset,
        0,
        ReaderMetrics.textInset,
        ReaderMetrics.sectionGap,
      );

  /// How many screens of text must lie ahead before the next surah is
  /// appended: an engineering margin, not a drawn value.
  static const double preloadViewports = 2;

  /// How far a margin mark's start edge lies beyond the text column's: the
  /// screen's edge, so the mark stands over the margin and its overhang
  /// lies on the line beside it (D-140, 1). The boards draw no margin marks
  /// in the surah-mode reader; the side and the reach are a reading, for the
  /// owner's device session.
  static const double marginMarkOutset = ReaderMetrics.textInset;

  /// The same for the bookmark ribbon, on the column's other side
  /// (`Mushaf.dc.html`, «علامة مرجعية»: «شريط زمردي في الهامش»).
  static const double ribbonOutset = ReaderMetrics.textInset;

  /// Where the ayah toolbar floats over the text: `space-3` from the edges of
  /// the reading area. The boards draw no toolbar (PRD §7.6 names it
  /// described, not drawn), so this is a reading from the tokens.
  static const EdgeInsets toolbarPadding = EdgeInsets.all(AppSpacing.space3);

  /// How far down the screen the surah that a pinch anchors in is taken to
  /// be: the middle, as the fingers of a pinch usually are. An engineering
  /// choice, not a drawn value.
  static const double pinchFocus = 0.5;

  /// The message of a reader with no verified pack, inset as a screen's
  /// body (`Search.dc.html`, «خطة الحفظ» body: `padding: 0 20px`).
  static const EdgeInsetsDirectional messagePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 20);

  /// `.qk-sheet`: `padding: var(--space-3) 22px 22px`.
  static const EdgeInsetsDirectional sheetPadding =
      EdgeInsetsDirectional.fromSTEB(22, AppSpacing.space3, 22, 22);

  /// `.qk-sheet`: `border-radius: var(--radius-sheet) var(--radius-sheet) 0 0`.
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(AppRadius.radiusSheet),
  );

  /// `.qk-sheet`: `gap: var(--space-4)`.
  static const double sheetGap = AppSpacing.space4;

  /// `.qk-sheet-handle`: `width: 44px; height: 5px`.
  static const Size handleSize = Size(44, 5);

  /// `.qk-sheet-handle`: `border-radius: 3px`.
  static const BorderRadius handleRadius = BorderRadius.all(Radius.circular(3));
}
