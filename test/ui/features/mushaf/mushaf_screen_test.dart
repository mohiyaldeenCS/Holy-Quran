import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/reader/page_mark.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/position_bar.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/surah_header.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';

import 'mushaf_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mushaf_screen');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  Future<MushafViewModel> pumpReader(
    WidgetTester tester, {
    QuranAddress? address,
    double textScale = 1,
  }) async {
    setReaderView(tester);
    final viewModel = rig.viewModel(address: address);
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(readerApp(viewModel, textScale: textScale));
    await tester.pumpAndSettle();
    return viewModel;
  }

  QuranAddress at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

  ScrollController controllerOf(WidgetTester tester) => tester
      .widget<CustomScrollView>(find.byType(CustomScrollView))
      .controller!;

  testWidgets('opens at the first ayah of the first surah with no address', (
    tester,
  ) async {
    final viewModel = await pumpReader(tester);

    expect(viewModel.status, ReaderStatus.ready);
    expect(viewModel.anchor, at(1, 1));
    expect(viewModel.position!.address, at(1, 1));
    expect(find.byType(PositionBar), findsOneWidget);
    expect(find.byType(SurahHeader), findsWidgets);
    expect(controllerOf(tester).offset, 0);
  });

  testWidgets('opens at the address of its route', (tester) async {
    final viewModel = await pumpReader(tester, address: at(2, 30));

    expect(viewModel.anchor, at(2, 30));
    expect(controllerOf(tester).offset, greaterThan(0));
    final first = viewModel.position!.address;
    expect(first.surah, 2);
    expect(first.ayah, inInclusiveRange(20, 30));
  });

  testWidgets('a word address opens its ayah', (tester) async {
    final viewModel = await pumpReader(
      tester,
      address: QuranAddress('hafs', 2, 30, 2),
    );

    expect(viewModel.anchor, at(2, 30));
    expect(controllerOf(tester).offset, greaterThan(0));
  });

  testWidgets('an address outside the edition opens the first ayah', (
    tester,
  ) async {
    final viewModel = await pumpReader(tester, address: at(2, 400));

    expect(viewModel.anchor, at(1, 1));
    final other = await pumpReader(tester, address: at(400, 1));
    expect(other.anchor, at(1, 1));
  });

  testWidgets('the position bar and the page number follow the scroll', (
    tester,
  ) async {
    final viewModel = await pumpReader(tester, address: at(2, 1));
    expect(viewModel.position!.juz, 1);
    expect(
      find.text(_l10n.juzHizbLine(arabicDigits(1), arabicDigits(1))),
      findsOneWidget,
    );
    expect(viewModel.position!.page, 2);
    expect(find.byType(PageMark), findsWidgets);

    final controller = controllerOf(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.pumpAndSettle();

    final position = viewModel.position!;
    expect(position.juz, 2);
    expect(position.address.surah, greaterThanOrEqualTo(2));
    expect(position.address.ayah, greaterThan(20));
    expect(
      find.text(
        _l10n.juzHizbLine(
          arabicDigits(position.juz),
          arabicDigits(position.hizb),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(_l10n.pageLabel(arabicDigits(position.page))),
      findsWidgets,
    );
  });

  testWidgets('continues into the next surah as the end comes near', (
    tester,
  ) async {
    final viewModel = await pumpReader(tester, address: at(2, 1));

    final controller = controllerOf(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.pumpAndSettle();

    final numbers = [for (final s in viewModel.surahs) s.info.number];
    expect(numbers.first, 2);
    expect(numbers, containsAllInOrder([2, 3]));
    expect(
      find.byType(SurahHeader, skipOffstage: false),
      findsNWidgets(numbers.length),
    );
  });

  testWidgets('fills the screen from a short surah', (tester) async {
    final viewModel = await pumpReader(tester, address: at(4, 1));

    expect(viewModel.surahs.length, greaterThan(1));
    expect(controllerOf(tester).position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('the last surah has no next one to load', (tester) async {
    final viewModel = await pumpReader(tester, address: at(9, 1));

    expect([for (final s in viewModel.surahs) s.info.number], [9]);
  });

  testWidgets('al-Tawba has no basmala line; others show the stored one', (
    tester,
  ) async {
    await pumpReader(tester, address: at(9, 1));
    expect(find.byType(QuranText), findsNothing);

    await pumpReader(tester, address: at(4, 1));
    expect(find.byType(QuranText), findsWidgets);
  });

  testWidgets('shows the information line only for a surah with its facts', (
    tester,
  ) async {
    await pumpReader(tester, address: at(4, 1));
    final line = _l10n.surahInfoLine(
      _l10n.revelationMadani,
      _l10n.ayahCount(1, arabicDigits(1)),
      arabicDigits(4),
    );
    expect(find.text(line), findsOneWidget);

    await pumpReader(tester, address: at(MushafRig.surahWithoutPlace, 1));
    expect(
      tester
          .widgetList<SurahHeader>(find.byType(SurahHeader))
          .where((header) => header.name == rig.index.surahs[1].name)
          .single
          .info,
      isNull,
    );
  });

  testWidgets('distraction free hides the bar and the page number, not the '
      'text', (tester) async {
    final viewModel = await pumpReader(tester, address: at(2, 1));

    viewModel.setDistractionFree(true);
    await tester.pump();

    expect(find.byType(PositionBar), findsNothing);
    expect(find.byType(PageMark), findsWidgets);
    expect(find.byType(SurahHeader), findsWidgets);
    expect(find.byType(CustomScrollView), findsOneWidget);

    viewModel.setDistractionFree(false);
    await tester.pump();
    expect(find.byType(PositionBar), findsOneWidget);
  });

  testWidgets('shows the integrity alert and no text without a verified pack', (
    tester,
  ) async {
    setReaderView(tester);
    final viewModel = MushafViewModel();
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(readerApp(viewModel));
    await tester.pumpAndSettle();

    expect(viewModel.status, ReaderStatus.unavailable);
    expect(find.byType(IntegrityAlert), findsOneWidget);
    expect(find.text(_l10n.integrityBaseTitle), findsOneWidget);
    expect(find.byType(MushafScreen), findsOneWidget);
    expect(find.byType(CustomScrollView), findsNothing);
    expect(find.byType(QuranText), findsNothing);
    expect(find.byType(PositionBar), findsNothing);
  });
}
