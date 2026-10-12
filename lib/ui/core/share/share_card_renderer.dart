import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:holyquran/ui/core/share/share_card_fit.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';

/// Lays out and paints a [ShareCard] away from the screen, with [context]'s
/// view, localizations and theme: to fit its ayah (SH-03) and to give the
/// image that is shared (SH-02). The card is the widget the sheet previews,
/// so what is measured and shared is what the user sees.
final class ShareCardRenderer {
  const ShareCardRenderer(this.context);

  final BuildContext context;

  /// The fit test of [card]'s ayah, by laying the card out at each font size
  /// asked. [card]'s own font size is ignored.
  ///
  /// [ShareCard] draws the 4:5 card; the other ratios keep its width and
  /// paddings with the height from the ratio (D-089, 2), so the ayah's
  /// column there gains or loses the difference in height.
  ShareCardFitTest fitTest(ShareCard card) {
    final excess = <double, _Excess>{};
    return (ratio, fontSize) {
      final measured = excess[fontSize] ??= _measure(
        ShareCard(
          ayah: card.ayah,
          surahName: card.surahName,
          ayahNumber: card.ayahNumber,
          ayahFontSize: fontSize,
          design: card.design,
        ),
      );
      final gained =
          ratio.heightFor(measured.card.width) - measured.card.height;
      return measured.overflow - gained <= precisionErrorTolerance;
    };
  }

  /// [card] painted as PNG bytes, [_exportWidth] pixels wide.
  Future<Uint8List> png(ShareCard card) async {
    final offscreen = _Offscreen(context, card, paint: true);
    try {
      final boundary = offscreen.boundary;
      final image = await boundary.toImage(
        pixelRatio: _exportWidth / boundary.size.width,
      );
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        return bytes!.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
    } finally {
      offscreen.dispose();
    }
  }

  _Excess _measure(ShareCard card) {
    final offscreen = _Offscreen(context, card, paint: false);
    try {
      final column = _ayahColumn(offscreen.root);
      var top = double.infinity;
      var bottom = double.negativeInfinity;
      for (var child = column.firstChild; child != null;) {
        final data = child.parentData! as FlexParentData;
        top = math.min(top, data.offset.dy);
        bottom = math.max(bottom, data.offset.dy + child.size.height);
        child = data.nextSibling;
      }
      return (
        card: offscreen.boundary.size,
        overflow: bottom - top - column.size.height,
      );
    } finally {
      offscreen.dispose();
    }
  }
}

/// How much taller than its column the ayah block of a 4:5 card of [card]'s
/// size is; negative when it has room to spare.
typedef _Excess = ({Size card, double overflow});

/// The vertical flex the card's [QuranText] sits in: the ayah block whose
/// children must fit its height.
RenderFlex _ayahColumn(Element root) {
  RenderObject? found;
  void visit(Element element) {
    if (element.widget is QuranText) {
      found = element.renderObject;
    } else if (found == null) {
      element.visitChildren(visit);
    }
  }

  visit(root);
  var node = found?.parent;
  while (node != null &&
      !(node is RenderFlex && node.direction == Axis.vertical)) {
    node = node.parent;
  }
  return node as RenderFlex? ??
      (throw StateError('The share card has no column around its ayah'));
}

/// One frame of [card] built and laid out in a tree of its own, and painted
/// when [paint] is set.
final class _Offscreen {
  _Offscreen(BuildContext context, ShareCard card, {required bool paint}) {
    final view = RenderView(
      view: View.of(context),
      configuration: const ViewConfiguration(
        logicalConstraints: BoxConstraints(),
        physicalConstraints: BoxConstraints(),
      ),
      child: RenderPositionedBox(alignment: Alignment.topLeft, child: boundary),
    );
    _pipeline.rootNode = view;
    view.prepareInitialFrame();
    root = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: MediaQuery(
        data: MediaQuery.of(context),
        child: Localizations.override(
          context: context,
          child: InheritedTheme.captureAll(context, card),
        ),
      ),
    ).attachToRenderTree(_build);
    _build
      ..buildScope(root)
      ..finalizeTree();
    _pipeline.flushLayout();
    // Only a card that fits is painted: painting an overflowing flex reports
    // the overflow as an error in debug builds.
    if (paint) {
      _pipeline
        ..flushCompositingBits()
        ..flushPaint();
    }
  }

  final boundary = RenderRepaintBoundary();
  final _pipeline = PipelineOwner();
  final _build = BuildOwner(focusManager: FocusManager());
  late final RenderObjectToWidgetElement<RenderBox> root;

  void dispose() {
    RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
    ).attachToRenderTree(_build, root);
    _build
      ..finalizeTree()
      ..focusManager.dispose();
    _pipeline
      ..rootNode = null
      ..dispose();
  }
}

// The shared image is 1080 pixels wide, the width social apps show a post at;
// the identity gives no export size.
const double _exportWidth = 1080;
