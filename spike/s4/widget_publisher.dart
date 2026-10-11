import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/utils/result.dart';

import 'ayah_widget_face.dart';
import 'widget_bridge.dart';
import 'widget_fit.dart';
import 'widget_slots.dart';

/// A candidate ayah, its text and its surah's name as the pack holds them.
typedef WidgetAyah = ({
  QuranAddress address,
  PackText ayah,
  PackText surahName,
});

typedef FaceRenderer =
    Future<Uint8List> Function(AyahWidgetFace face, double pixelRatio);

/// The logical size of each face: Share.dc.html line 89 draws the 4x2 widget
/// at 364 by 170; the 2x2 is the same face, square (D-093, reading 1).
Size faceSizeOf(WidgetFaceSize size) => switch (size) {
  WidgetFaceSize.medium => const Size(364, 170),
  WidgetFaceSize.small => const Size(170, 170),
};

/// What was published: the slots of each face, and the candidates each face
/// skipped because no size from 28 to 22 fits them whole (WG-03).
final class WidgetPublication {
  const WidgetPublication({required this.slots, required this.skipped});

  final Map<WidgetFaceSize, List<WidgetSlotInfo>> slots;
  final Map<WidgetFaceSize, List<QuranAddress>> skipped;
}

/// A publish that stopped at [call]: nothing after it was done, and what was
/// done before it stays. Images saved before the slots may replace files the
/// old slots name; the native widget refuses an image whose length is not the
/// slot's, so it shows nothing rather than another ayah's image.
final class WidgetPublishFailure implements Exception {
  const WidgetPublishFailure(this.call, this.cause);

  final String call;
  final Object cause;

  @override
  String toString() => 'WidgetPublishFailure: $call: $cause';
}

/// Renders a week of ayah faces and hands them to the native widget (S4
/// approach A, D-094): images, the slots naming them, the labels a screen
/// reader speaks, the redraw schedule and a redraw. No ayah text leaves
/// Dart.
final class WidgetPublisher {
  WidgetPublisher(
    this._bridge, {
    this._now = DateTime.now,
    this._render = renderFacePng,
  });

  final WidgetBridge _bridge;
  final DateTime Function() _now;
  final FaceRenderer _render;

  static final _sha256 = RegExp(r'^[0-9a-f]{64}$');

  /// For each face, the first [days] of [candidates] that fit it, one per
  /// local day from today; [packTextSha256] is the verified manifest's
  /// digest of `text.sqlite`.
  Future<Result<WidgetPublication>> publish(
    List<WidgetAyah> candidates, {
    required String packTextSha256,
    required double pixelRatio,
    int days = 7,
  }) async {
    if (!_sha256.hasMatch(packTextSha256)) {
      throw ArgumentError.value(packTextSha256, 'packTextSha256');
    }
    if (pixelRatio <= 0) throw ArgumentError.value(pixelRatio, 'pixelRatio');
    for (final candidate in candidates) {
      if (candidate.address.isWord) {
        throw ArgumentError.value(candidate.address, 'candidates');
      }
    }
    final starts = slotStarts(_now(), days);
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final slots = <WidgetFaceSize, List<WidgetSlotInfo>>{};
    final skipped = <WidgetFaceSize, List<QuranAddress>>{};
    final labels = <QuranAddress, String>{};

    Future<T> step<T>(String call, Future<T> Function() run) async {
      try {
        return await run();
      } on Exception catch (error) {
        throw WidgetPublishFailure(call, error);
      }
    }

    try {
      for (final size in WidgetFaceSize.values) {
        final faceSize = faceSizeOf(size);
        final box = AyahWidgetFace.ayahBoxOf(faceSize);
        final sizeSlots = slots[size] = [];
        final sizeSkipped = skipped[size] = [];
        for (final candidate in candidates) {
          if (sizeSlots.length == starts.length) break;
          final quranSize = fitQuranSize(candidate.ayah, box);
          if (quranSize == null) {
            sizeSkipped.add(candidate.address);
            continue;
          }
          final index = sizeSlots.length;
          AyahWidgetFace face(WidgetLook look) => AyahWidgetFace(
            ayah: candidate.ayah,
            surahName: candidate.surahName,
            ayahNumber: candidate.address.ayah,
            quranSize: quranSize,
            look: look,
            size: faceSize,
          );
          final clock = Stopwatch()..start();
          final light = await step(
            'renderFacePng',
            () => _render(face(WidgetLook.paper), pixelRatio),
          );
          final dark = await step(
            'renderFacePng',
            () => _render(face(WidgetLook.night), pixelRatio),
          );
          final renderMs = clock.elapsedMilliseconds;
          final lightKey = imageKey(size, index, night: false);
          final darkKey = imageKey(size, index, night: true);
          final lightPath = await step(
            'savePng($lightKey)',
            () => _bridge.savePng(lightKey, light),
          );
          final darkPath = await step(
            'savePng($darkKey)',
            () => _bridge.savePng(darkKey, dark),
          );
          sizeSlots.add((
            address: candidate.address.toString(),
            slotStartMs: starts[index].millisecondsSinceEpoch,
            lightPath: lightPath,
            darkPath: darkPath,
            packTextSha256: packTextSha256,
            lightBytes: light.length,
            darkBytes: dark.length,
            renderMs: renderMs,
          ));
          // Spike only: the label is built here, outside SurahName (D-084),
          // because the native widget cannot draw a pack string. A surah
          // name is not Quran text; that it may leave Dart whole as a label
          // is for D-094 to record.
          labels[candidate.address] = l10n.surahTitleAyahReference(
            candidate.surahName.verbatim,
            arabicDigits(candidate.address.ayah),
          );
        }
      }
      for (final size in WidgetFaceSize.values) {
        final key = slotsKey(size);
        await step(
          'saveString($key)',
          () => _bridge.saveString(key, encodeSlots(slots[size]!)),
        );
      }
      await step(
        'saveString($labelsKey)',
        () => _bridge.saveString(labelsKey, encodeLabels(labels)),
      );
      final longest = slots.values.fold(
        0,
        (most, list) => list.length > most ? list.length : most,
      );
      await step(
        'scheduleUpdates',
        () => _bridge.scheduleUpdates(starts.sublist(0, longest)),
      );
      await step('update', _bridge.update);
    } on WidgetPublishFailure catch (failure) {
      return Failure(failure);
    }
    return Ok(WidgetPublication(slots: slots, skipped: skipped));
  }
}

/// [face] as PNG bytes at [pixelRatio], drawn offscreen with no app above it,
/// as `HomeWidget.renderFlutterWidget` draws but without its left-to-right
/// column and without writing a file. The face is the root: it brings its own
/// media query, localizations, direction and theme.
Future<Uint8List> renderFacePng(AyahWidgetFace face, double pixelRatio) async {
  final boundary = RenderRepaintBoundary();
  final pipelineOwner = PipelineOwner();
  final focusManager = FocusManager();
  final buildOwner = BuildOwner(focusManager: focusManager);
  final renderView = RenderView(
    view: ui.PlatformDispatcher.instance.implicitView!,
    child: RenderPositionedBox(child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(face.size),
      devicePixelRatio: pixelRatio,
    ),
  );
  RenderObjectToWidgetElement<RenderBox>? root;
  try {
    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();
    root = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: face,
    ).attachToRenderTree(buildOwner);
    buildOwner
      ..buildScope(root)
      ..finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('the face did not encode as PNG');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
    }
  } finally {
    if (root != null) {
      // An adapter without a child unmounts the face's elements.
      RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
      ).attachToRenderTree(buildOwner, root);
      buildOwner
        ..buildScope(root)
        ..finalizeTree();
    }
    pipelineOwner.rootNode = null;
    renderView.dispose();
    pipelineOwner.dispose();
    focusManager.dispose();
  }
}
