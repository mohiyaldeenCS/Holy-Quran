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

  /// The fit test of [card]'s ayah, by laying the card out at each ratio and
  /// font size asked. [card]'s own ratio and font size are ignored.
  ShareCardFitTest fitTest(ShareCard card) {
    final overflow = <(ShareCardRatio, double), double>{};
    return (ratio, fontSize) {
      final excess = overflow[(ratio, fontSize)] ??= _measure(
        ShareCard(
          ayah: card.ayah,
          surahName: card.surahName,
          ayahNumber: card.ayahNumber,
          ayahFontSize: fontSize,
          design: card.design,
          ratio: ratio,
        ),
      );
      return excess <= precisionErrorTolerance;
    };
  }

  /// [card] painted as PNG bytes, [_exportWidth] pixels wide and as tall as
  /// its ratio gives. Throws
  /// [ShareCardPaintFailed] when the engine gives no bytes.
  Future<Uint8List> png(ShareCard card) async {
    final offscreen = _Offscreen();
    try {
      offscreen.mount(context, card, paint: true);
      final boundary = offscreen.boundary;
      // The engine rounds the image's size up, and the 9:16 card's height
      // times the ratio lands a rounding error above 1920; a hair less keeps
      // every size at exactly 1080 wide.
      final image = await boundary.toImage(
        pixelRatio:
            _exportWidth / boundary.size.width - precisionErrorTolerance,
      );
      try {
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.png) ??
            (throw const ShareCardPaintFailed());
        return bytes.buffer.asUint8List(
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

  /// How much taller than its column the ayah block of [card] is; negative
  /// when it has room to spare.
  double _measure(ShareCard card) {
    final offscreen = _Offscreen();
    try {
      offscreen.mount(context, card, paint: false);
      final column = _ayahColumn(offscreen.root);
      var top = double.infinity;
      var bottom = double.negativeInfinity;
      for (var child = column.firstChild; child != null;) {
        final data = child.parentData! as FlexParentData;
        top = math.min(top, data.offset.dy);
        bottom = math.max(bottom, data.offset.dy + child.size.height);
        child = data.nextSibling;
      }
      return bottom - top - column.size.height;
    } finally {
      offscreen.dispose();
    }
  }
}

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

/// A tree of its own for one frame of a card: [mount] builds and lays it
/// out, and paints it when asked; [dispose] frees all of it, whether or not
/// [mount] finished.
final class _Offscreen {
  final boundary = RenderRepaintBoundary();
  late final _positioned = RenderPositionedBox(
    alignment: Alignment.topLeft,
    child: boundary,
  );
  final _pipeline = PipelineOwner();
  final _build = BuildOwner(focusManager: FocusManager());
  RenderView? _view;
  RenderObjectToWidgetElement<RenderBox>? _root;

  Element get root => _root!;

  void mount(BuildContext context, ShareCard card, {required bool paint}) {
    final view = _view = RenderView(
      view: View.of(context),
      configuration: const ViewConfiguration(
        logicalConstraints: BoxConstraints(),
        physicalConstraints: BoxConstraints(),
      ),
      child: _positioned,
    );
    _pipeline.rootNode = view;
    view.prepareInitialFrame();
    final root = _root = RenderObjectToWidgetAdapter<RenderBox>(
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

  void dispose() {
    if (_root case final root?) {
      RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
          .attachToRenderTree(_build, root);
    }
    _build
      ..finalizeTree()
      ..focusManager.dispose();
    _pipeline
      ..rootNode = null
      ..dispose();
    _view?.dispose();
    _positioned.dispose();
    boundary.dispose();
  }
}

/// The card could not be painted as PNG bytes.
final class ShareCardPaintFailed implements Exception {
  const ShareCardPaintFailed();

  @override
  String toString() => 'ShareCardPaintFailed()';
}

// The shared image is 1080 pixels wide, the width social apps show a post at;
// the identity gives no export size.
const double _exportWidth = 1080;
