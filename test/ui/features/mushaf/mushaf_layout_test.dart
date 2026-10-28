import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/reader/page_mark.dart';
import 'package:holyquran/ui/core/widgets/position_bar.dart';
import 'package:holyquran/ui/core/widgets/surah_header.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';

import 'mushaf_harness.dart';

/// What a page mark of the engine may overshoot an edge by at 200%: a
/// rounding of 0.9 logical pixels, not a clip.
const _rounding = 1.0;

/// The sizes the reader is checked at: a small phone upright and on its side.
const _portrait = Size(320, 640);
const _landscape = Size(640, 320);

void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mushaf_layout');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  QuranAddress at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

  /// Nothing the reader draws sticks out of the view sideways, and nothing
  /// threw while laying it out.
  void expectWithin(WidgetTester tester, Size size, String where) {
    expect(tester.takeException(), isNull, reason: where);
    final finders = [
      find.byType(RichText),
      find.byType(PositionBar),
      find.byType(SurahHeader),
      find.byType(PageMark),
    ];
    for (final finder in finders) {
      for (final element in finder.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.left, greaterThanOrEqualTo(-_rounding), reason: where);
        expect(
          rect.right,
          lessThanOrEqualTo(size.width + _rounding),
          reason: where,
        );
      }
    }
  }

  for (final (name, size) in [
    ('portrait', _portrait),
    ('landscape', _landscape),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('at ${scale * 100}% in $name nothing is clipped from the '
          'first surah to the last', (tester) async {
        setReaderView(tester, size);
        final viewModel = rig.viewModel();
        addTearDown(viewModel.dispose);
        await tester.pumpWidget(
          readerApp(viewModel, textScale: scale, size: size),
        );
        await tester.pumpAndSettle();
        expectWithin(tester, size, 'opened');

        final controller = scrollOf(tester);
        final last = rig.index.surahCount;
        for (var step = 0; step < 2000; step++) {
          final position = controller.position;
          if (position.pixels >= position.maxScrollExtent &&
              viewModel.surahs.last.info.number == last) {
            break;
          }
          controller.jumpTo(
            (position.pixels + position.viewportDimension / 2).clamp(
              0,
              position.maxScrollExtent,
            ),
          );
          await tester.pumpAndSettle();
          expectWithin(tester, size, 'scrolled to ${position.pixels}');
        }
        expect(viewModel.surahs.last.info.number, last);
        expect(controller.position.pixels, controller.position.maxScrollExtent);
      });
    }
  }

  group('the place is kept', () {
    Future<MushafViewModel> openAt(WidgetTester tester) async {
      setReaderView(tester, _portrait);
      final viewModel = rig.viewModel(address: at(2, 30));
      addTearDown(viewModel.dispose);
      await tester.pumpWidget(readerApp(viewModel, size: _portrait));
      await tester.pumpAndSettle();
      expect(viewModel.status, ReaderStatus.ready);
      return viewModel;
    }

    testWidgets('when the phone is turned on its side and back', (
      tester,
    ) async {
      final viewModel = await openAt(tester);
      final place = viewModel.position!.address;

      setReaderView(tester, _landscape);
      await tester.pumpWidget(readerApp(viewModel, size: _landscape));
      await tester.pumpAndSettle();
      expect(viewModel.position!.address, place);

      setReaderView(tester, _portrait);
      await tester.pumpWidget(readerApp(viewModel, size: _portrait));
      await tester.pumpAndSettle();
      expect(viewModel.position!.address, place);
    });

    testWidgets('when the text size changes', (tester) async {
      final viewModel = await openAt(tester);
      final place = viewModel.position!.address;

      await tester.pumpWidget(
        readerApp(viewModel, textScale: 2, size: _portrait),
      );
      await tester.pumpAndSettle();
      expect(viewModel.position!.address, place);

      await tester.pumpWidget(readerApp(viewModel, size: _portrait));
      await tester.pumpAndSettle();
      expect(viewModel.position!.address, place);
    });
  });
}
