import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_reader_screen.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_sheet.dart';

import '../../../../testing/packs/synthetic_tafsir_pack.dart';
import 'tafsir_fixture.dart';
import 'tafsir_harness.dart';

void main() {
  QuranAddress at(TafsirFixture fixture, int surah, int ayah) =>
      QuranAddress(fixture.quran.riwaya, surah, ayah);

  tafsirTest('the study tab opens the reader at the address of its route', (
    tester,
    fixture,
  ) async {
    final router = await pumpApp(tester, fixture);

    router.go(Routes.studyTafsir(at(fixture, 2, 1)));
    await settle(tester, until: find.byType(AyahRow));

    expect(find.byType(TafsirReaderScreen), findsOneWidget);
    expect(tester.widget<AyahRow>(find.byType(AyahRow)).number, 1);
    expect(passageOf(defaultSyntheticPassages[1].text), findsOneWidget);
  });

  tafsirTest('a route with an address that is not canonical goes home', (
    tester,
    fixture,
  ) async {
    final router = await pumpApp(tester, fixture);

    router.go('${Routes.study}/tafsir/not-an-address');
    await tester.pumpAndSettle();

    expect(find.byType(TafsirReaderScreen), findsNothing);
    expect(router.state.uri.path, Routes.home);
  });

  tafsirTest('the reader shows the ayah alone while the app provides no '
      'tafsirs', (tester, fixture) async {
    final router = await pumpApp(tester, fixture, tafsirs: false);

    router.go(Routes.studyTafsir(at(fixture, 2, 1)));
    await settle(tester, until: find.byType(AyahRow));

    expect(find.byType(AyahRow), findsOneWidget);
    expect(find.text(tafsirL10n.noTafsirsYet), findsOneWidget);
  });

  tafsirTest('the sheet opens over the page it came from and its reader '
      'button goes to the reader', (tester, fixture) async {
    final router = await pumpApp(tester, fixture);

    unawaited(router.push(Routes.tafsirSheet(at(fixture, 2, 2))));
    await settle(tester, until: find.byType(AyahRow));
    expect(find.byType(TafsirSheet), findsOneWidget);
    expect(passageOf(defaultSyntheticPassages[2].text), findsOneWidget);

    await tester.tap(buttonLabelled(tafsirL10n.tafsirReaderTitle));
    final readerAyah = find.descendant(
      of: find.byType(TafsirReaderScreen),
      matching: find.byType(AyahRow),
    );
    await settle(tester, until: readerAyah);

    expect(find.byType(TafsirSheet), findsNothing);
    expect(find.byType(TafsirReaderScreen), findsOneWidget);
    expect(router.state.uri.path, Routes.studyTafsir(at(fixture, 2, 2)));
    expect(tester.widget<AyahRow>(find.byType(AyahRow)).number, 2);
  });

  tafsirTest('a sheet opened cold does not stay over nothing', (
    tester,
    fixture,
  ) async {
    final router = await pumpApp(tester, fixture);

    router.go(Routes.tafsirSheet(at(fixture, 2, 2)));
    await tester.pumpAndSettle();

    expect(find.byType(TafsirSheet), findsNothing);
  });
}
