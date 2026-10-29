import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/surah_header.dart';
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

  Future<void> pumpReader(
    WidgetTester tester,
    QuranAddress address, {
    double scale = 1,
  }) async {
    setReaderView(tester);
    viewModel = rig.viewModel(
      address: address,
      settings: FakeAppSettingsRepository(surahTextScale: scale),
    );
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(readerApp(viewModel));
    await tester.pumpAndSettle();
  }

  /// The end-of-ayah markers inside the reading area, in the screen's
  /// coordinates.
  List<_Marker> visibleMarkers(WidgetTester tester, {bool anywhere = false}) {
    final markers = <_Marker>[];
    for (final element in find.byType(ReaderBlock).evaluate()) {
      final block = element.widget as ReaderBlock;
      final origin = tester.getTopLeft(find.byWidget(block));
      final layout = block.layout;
      for (final ayah in layout.ayat) {
        final center = origin + layout.markerRect(ayah)!.center;
        // Where fingers can be put, or, after a step, anywhere on screen: the
        // marker of an ayah moves along its line when the line breaks again.
        if (anywhere
            ? center.dy > 0 && center.dy < readerHeight
            : center.dy > 90 &&
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
    for (final marker in visibleMarkers(tester, anywhere: true)) {
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

  // The short surahs after the first are a header, a basmala and a line or
  // two each: scroll until the top line is in one surah and the last marker
  // on screen is in the next.
  Future<_Marker> scrollToBoundary(WidgetTester tester) async {
    final controller = scrollOf(tester);
    for (var step = 0; step < 40; step++) {
      final top = viewModel.position!.address.surah;
      final markers = visibleMarkers(tester);
      if (markers.isNotEmpty && markers.last.surah != top) return markers.last;
      controller.jumpTo(controller.offset + 40);
      await tester.pumpAndSettle();
    }
    fail('no surah boundary on screen');
  }

  for (final (name, scale, from, to) in [
    ('out', 1.0, 80.0, 130.0),
    ('in', 1.5, 130.0, 80.0),
  ]) {
    testWidgets('fingers on the lower surah, pinching $name, with the top '
        'line in the one above', (tester) async {
      await pumpReader(tester, QuranAddress('hafs', 4, 1), scale: scale);
      final lower = await scrollToBoundary(tester);
      expect(lower.surah, greaterThan(viewModel.position!.address.surah));
      await pinchKeeps(tester, lower, from: from, to: to);
    });
  }

  /// The ayah the top of the reading area is in: the last one, in screen
  /// order, whose text begins at or above the top edge; where the top edge is
  /// over a header or a basmala, the first one below it.
  ({int surah, int ayah, double start}) topAyah(WidgetTester tester) {
    final edge = tester.getTopLeft(find.byType(CustomScrollView)).dy + 1;
    ({int surah, int ayah, double start})? containing;
    ({int surah, int ayah, double start})? next;
    for (final element in find.byType(ReaderBlock).evaluate()) {
      final block = element.widget as ReaderBlock;
      final origin = tester.getTopLeft(find.byWidget(block));
      for (final ayah in block.layout.ayat) {
        final start = origin.dy + (block.layout.topOfAyah(ayah) ?? 0);
        final end = origin.dy + block.layout.markerRect(ayah)!.bottom;
        final found = (
          surah: block.layout.plan.text.surah,
          ayah: ayah,
          start: start,
        );
        if (start <= edge && end > edge) {
          if (containing == null || start > containing.start) {
            containing = found;
          }
        } else if (start > edge && (next == null || start < next.start)) {
          next = found;
        }
      }
    }
    return containing ?? next ?? fail('no ayah in the reading area');
  }

  /// Where the text of an ayah begins on screen; null when it is not on it.
  double? ayahStart(WidgetTester tester, int surah, int ayah) {
    for (final element in find.byType(ReaderBlock).evaluate()) {
      final block = element.widget as ReaderBlock;
      if (block.layout.plan.text.surah != surah) continue;
      final top = block.layout.topOfAyah(ayah);
      if (top == null) continue;
      return tester.getTopLeft(find.byWidget(block)).dy + top;
    }
    return null;
  }

  double lineHeight(WidgetTester tester) => tester
      .widgetList<ReaderBlock>(find.byType(ReaderBlock))
      .first
      .layout
      .plan
      .lineHeight;

  // The header of a surah below the one the top of the screen is in, and its
  // basmala, both on screen.
  Future<({Offset header, Offset basmala})> scrollToLowerHeader(
    WidgetTester tester,
  ) async {
    final controller = scrollOf(tester);
    for (var step = 0; step < 400; step++) {
      final headers = find
          .byType(SurahHeader)
          .evaluate()
          .map((e) => tester.getCenter(find.byWidget(e.widget)));
      final inRange = headers.where((h) => h.dy > 150 && h.dy < 420);
      final basmalas = find
          .byType(QuranText)
          .evaluate()
          .map((e) => tester.getCenter(find.byWidget(e.widget)));
      if (inRange.isNotEmpty) {
        final header = inRange.last;
        final below = basmalas.where(
          (b) => b.dy > header.dy && b.dy < readerHeight - 60,
        );
        // The surah whose text is nearest below the header.
        ({double y, int surah})? lower;
        for (final element in find.byType(ReaderBlock).evaluate()) {
          final y = tester.getTopLeft(find.byWidget(element.widget)).dy;
          if (y > header.dy && (lower == null || y < lower.y)) {
            lower = (
              y: y,
              surah: (element.widget as ReaderBlock).layout.plan.text.surah,
            );
          }
        }
        final top = topAyah(tester);
        // The top edge is inside an ayah of the surah above.
        if (below.isNotEmpty &&
            lower != null &&
            lower.surah != top.surah &&
            top.start <= tester.getTopLeft(find.byType(CustomScrollView)).dy) {
          return (header: header, basmala: below.first);
        }
      }
      controller.jumpTo(controller.offset + 40);
      await tester.pumpAndSettle();
    }
    fail('no lower surah header on screen');
  }

  for (final (name, onBasmala, scale, from, to) in [
    ('header, out', false, 1.0, 80.0, 130.0),
    ('header, in', false, 1.5, 130.0, 80.0),
    ('basmala, out', true, 1.0, 80.0, 130.0),
    ('basmala, in', true, 1.5, 130.0, 80.0),
  ]) {
    testWidgets(
      'fingers on the $name of a lower surah keep the ayah at the top',
      (tester) async {
        // The long surah 2 is followed by surah 3: the top line is in an ayah
        // of 2 that is not its first, with 3's header lower down.
        await pumpReader(tester, QuranAddress('hafs', 2, 30), scale: scale);
        final target = await scrollToLowerHeader(tester);
        // The first visible ayah as the reader counts it: the one the top
        // line starts in.
        final first = viewModel.position!.address;
        final before = ayahStart(tester, first.surah, first.ayah);
        final stepBefore = viewModel.textStep;
        await pinch(
          tester,
          onBasmala ? target.basmala : target.header,
          from: from,
          to: to,
        );
        expect(viewModel.textStep, isNot(stepBefore));
        final after = ayahStart(tester, first.surah, first.ayah);
        final edge = tester.getTopLeft(find.byType(CustomScrollView)).dy;
        expect(
          after,
          isNotNull,
          reason:
              'the first visible ayah ${first.surah}:${first.ayah} is on '
              'screen (it started at $before)',
        );
        expect(
          (after! - edge).abs(),
          lessThanOrEqualTo(lineHeight(tester)),
          reason:
              'the first visible ayah ${first.surah}:${first.ayah} started at '
              '$before and is at $after, the top edge at $edge',
        );
      },
    );
  }

  // Scrolls on from 1:1 until the top edge is in the gap above surah 2, so
  // that its header is on screen just below the top and the first visible
  // ayah is 2:1: the surah in focus is the one holding the first visible
  // line, and a pinch on its header or basmala holds no ayah to anchor.
  Future<({Offset header, Offset basmala})> scrollToHeaderAtTop(
    WidgetTester tester,
  ) async {
    final controller = scrollOf(tester);
    final edge = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    for (var step = 0; step < 400; step++) {
      final headers = [
        for (final element in find.byType(SurahHeader).evaluate())
          tester.getCenter(find.byWidget(element.widget)),
      ].where((h) => h.dy > edge + 30 && h.dy < edge + 140);
      final basmalas = [
        for (final element in find.byType(QuranText).evaluate())
          tester.getCenter(find.byWidget(element.widget)),
      ];
      if (headers.isNotEmpty &&
          viewModel.position!.address == QuranAddress('hafs', 2, 1)) {
        final header = headers.first;
        final below = basmalas.where((b) => b.dy > header.dy);
        if (below.isNotEmpty) {
          return (header: header, basmala: below.first);
        }
      }
      controller.jumpTo(controller.offset + 20);
      await tester.pumpAndSettle();
    }
    fail('surah 2 never came to the top');
  }

  for (final (name, onBasmala, scale, from, to) in [
    ('header, out', false, 1.0, 70.0, 110.0),
    ('header, in', false, 1.5, 110.0, 70.0),
    ('basmala, out', true, 1.0, 70.0, 110.0),
    ('basmala, in', true, 1.5, 110.0, 70.0),
  ]) {
    testWidgets('fingers on the $name of the surah at the top keep its header '
        'at the top', (tester) async {
      await pumpReader(tester, QuranAddress('hafs', 1, 1), scale: scale);
      final target = await scrollToHeaderAtTop(tester);
      final edge = tester.getTopLeft(find.byType(CustomScrollView)).dy;
      double? headerTop() {
        final tops = [
          for (final element in find.byType(SurahHeader).evaluate())
            tester.getTopLeft(find.byWidget(element.widget)).dy,
        ]..sort((a, b) => (a - edge).abs().compareTo((b - edge).abs()));
        return tops.firstOrNull;
      }

      final before = headerTop();
      final stepBefore = viewModel.textStep;
      await pinch(
        tester,
        onBasmala ? target.basmala : target.header,
        from: from,
        to: to,
      );
      expect(viewModel.textStep, isNot(stepBefore));
      final after = headerTop();
      expect(after, isNotNull, reason: 'a header is on screen');
      expect(
        (after! - edge).abs(),
        lessThanOrEqualTo(lineHeight(tester)),
        reason:
            'the header of surah 2 was at $before and is at $after, the '
            'top edge at $edge',
      );
    });
  }
}
