import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import 'mushaf_harness.dart';

typedef _Marker = ({int surah, int ayah, Offset center, double lineHeight});

/// A pinch keeps the ayah under the fingers where it is, within a line of the
/// new size: the ayah is kept at the same fraction of its height, and its
/// height changes in whole lines.
void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mushaf_pinch_anchor');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  late MushafViewModel viewModel;

  Future<void> pumpReader(WidgetTester tester, QuranAddress address) async {
    setReaderView(tester);
    viewModel = rig.viewModel(
      address: address,
      settings: FakeAppSettingsRepository(),
    );
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(readerApp(viewModel));
    await tester.pumpAndSettle();
  }

  /// The end-of-ayah markers inside the reading area, in the screen's
  /// coordinates.
  List<_Marker> visibleMarkers(WidgetTester tester) {
    final markers = <_Marker>[];
    for (final element in find.byType(ReaderBlock).evaluate()) {
      final block = element.widget as ReaderBlock;
      final origin = tester.getTopLeft(find.byWidget(block));
      final layout = block.layout;
      for (final ayah in layout.ayat) {
        final center = origin + layout.markerRect(ayah)!.center;
        if (center.dy > 90 &&
            center.dy < 540 &&
            center.dx > 50 &&
            center.dx < 310) {
          markers.add((
            surah: layout.plan.text.surah,
            ayah: ayah,
            center: center,
            lineHeight: layout.plan.lineHeight,
          ));
        }
      }
    }
    return markers..sort((a, b) => a.center.dy.compareTo(b.center.dy));
  }

  _Marker? find_(WidgetTester tester, int surah, int ayah) {
    for (final marker in visibleMarkers(tester)) {
      if (marker.surah == surah && marker.ayah == ayah) return marker;
    }
    return null;
  }

  Future<void> pinch(
    WidgetTester tester,
    Offset at, {
    required double from,
    required double to,
  }) async {
    final a = await tester.startGesture(at - Offset(from / 2, 0));
    final b = await tester.startGesture(at + Offset(from / 2, 0));
    await tester.pump();
    await a.moveTo(at - Offset(to / 2, 0));
    await b.moveTo(at + Offset(to / 2, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
  }

  /// Pinches over [marker] and checks that its ayah's marker stays where the
  /// fingers were, within a line of the larger of the two plans.
  Future<void> pinchKeeps(
    WidgetTester tester,
    _Marker marker, {
    required double from,
    required double to,
  }) async {
    final stepBefore = viewModel.textStep;
    await pinch(tester, marker.center, from: from, to: to);
    expect(viewModel.textStep, isNot(stepBefore), reason: 'the step changed');
    final after = find_(tester, marker.surah, marker.ayah);
    expect(after, isNotNull, reason: 'the ayah is still under the fingers');
    final tolerance = marker.lineHeight > after!.lineHeight
        ? marker.lineHeight
        : after.lineHeight;
    expect(
      (after.center.dy - marker.center.dy).abs(),
      lessThanOrEqualTo(tolerance),
      reason:
          'ayah ${marker.surah}:${marker.ayah} moved from '
          '${marker.center.dy} to ${after.center.dy}',
    );
  }

  testWidgets('the first pinch keeps a late ayah under the fingers', (
    tester,
  ) async {
    await pumpReader(tester, QuranAddress('hafs', 2, 30));
    final marker = visibleMarkers(tester).firstWhere((m) => m.surah == 2);
    expect(marker.ayah, greaterThan(25), reason: 'scrolled to a later ayah');
    await pinchKeeps(tester, marker, from: 80, to: 130);
    expect(readerTextSteps[viewModel.textStep], greaterThan(1));
  });

  testWidgets('pinching in keeps it too', (tester) async {
    await pumpReader(tester, QuranAddress('hafs', 2, 30));
    final marker = visibleMarkers(tester).firstWhere((m) => m.surah == 2);
    await pinchKeeps(tester, marker, from: 130, to: 80);
    expect(readerTextSteps[viewModel.textStep], lessThan(1));
  });

  testWidgets('a pinch after the middle surah changed keeps its ayah', (
    tester,
  ) async {
    await pumpReader(tester, QuranAddress('hafs', 4, 1));
    final first = visibleMarkers(tester).first;
    await pinchKeeps(tester, first, from: 80, to: 130);

    final controller = scrollOf(tester);
    controller.jumpTo(controller.offset + 700);
    await tester.pumpAndSettle();
    final later = visibleMarkers(tester).last;
    expect(later.surah, greaterThan(first.surah));
    await pinchKeeps(tester, later, from: 130, to: 80);
  });

  testWidgets('fingers over a surah other than the middle one keep their '
      'ayah', (tester) async {
    await pumpReader(tester, QuranAddress('hafs', 4, 1));
    final controller = scrollOf(tester);
    // The short surahs after the first are each a header, a basmala and a
    // line or two; scroll until the end of one and the start of the next are
    // both on screen.
    for (var step = 0; step < 12; step++) {
      if ({for (final m in visibleMarkers(tester)) m.surah}.length > 1) break;
      controller.jumpTo(controller.offset + 60);
      await tester.pumpAndSettle();
    }
    final markers = visibleMarkers(tester);
    final surahs = {for (final m in markers) m.surah};
    expect(surahs.length, greaterThan(1), reason: 'two surahs on screen');

    // The top marker and the bottom one lie in different surahs, so at least
    // one of them is not in the surah at the middle of the screen.
    await pinchKeeps(tester, markers.first, from: 80, to: 130);
    final again = visibleMarkers(tester);
    await pinchKeeps(tester, again.last, from: 130, to: 80);
  });
}
