import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/source_badge.dart';
import 'package:holyquran/ui/features/tafsir/views/default_tafsir_picker.dart';

import '../../../../testing/packs/synthetic_tafsir_pack.dart';
import 'tafsir_fixture.dart';
import 'tafsir_harness.dart';

void main() {
  QuranAddress at(TafsirFixture fixture, int surah, int ayah) =>
      QuranAddress(fixture.quran.riwaya, surah, ayah);

  tafsirTest('shows the ayah above its passage in the sheet frame', (
    tester,
    fixture,
  ) async {
    final model = await openModel(tester, fixture, at(fixture, 1, 2));
    await pumpScreen(tester, sheetOf(model), sheet: true);

    expect(find.byType(CopySheetFrame), findsOneWidget);
    expect(find.byType(AyahRow), findsOneWidget);
    expect(passageOf(defaultSyntheticPassages[0].text), findsOneWidget);
    expect(find.text(tafsirL10n.tafsirRange('١', '٣')), findsOneWidget);
    expect(find.byType(SourceBadge), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(AyahRow)).dy,
      lessThan(
        tester.getTopLeft(passageOf(defaultSyntheticPassages[0].text)).dy,
      ),
    );
  });

  tafsirTest('steps between ayat', (tester, fixture) async {
    final model = await openModel(tester, fixture, at(fixture, 2, 1));
    await pumpScreen(tester, sheetOf(model), sheet: true);

    await tester.tap(buttonLabelled(tafsirL10n.playerNextAyah));
    await settle(tester);

    expect(model.address, at(fixture, 2, 2));
    expect(passageOf(defaultSyntheticPassages[2].text), findsOneWidget);
  });

  tafsirTest('opens the full reader at the ayah it shows', (
    tester,
    fixture,
  ) async {
    var opened = 0;
    final model = await openModel(tester, fixture, at(fixture, 2, 1));
    await pumpScreen(
      tester,
      sheetOf(model, onOpenReader: () => opened++),
      sheet: true,
    );

    await tester.tap(buttonLabelled(tafsirL10n.tafsirReaderTitle));

    expect(opened, 1);
  });

  tafsirTest('does not hold the list the default tafsir is chosen from', (
    tester,
    fixture,
  ) async {
    final model = await openModel(tester, fixture, at(fixture, 2, 1));
    await pumpScreen(tester, sheetOf(model), sheet: true);

    expect(find.byType(DefaultTafsirPicker), findsNothing);
  });

  tafsirTest('with no tafsir downloaded it shows the ayah and says so', (
    tester,
    fixture,
  ) async {
    final model = await openModel(tester, fixture, at(fixture, 2, 1));
    await pumpScreen(tester, sheetOf(model), sheet: true);

    expect(find.text(tafsirL10n.noTafsirsYet), findsOneWidget);
    expect(find.byType(AyahRow), findsOneWidget);
    expect(find.byType(SourceBadge), findsNothing);
    expect(find.byType(Button), findsNothing);
  }, install: false);

  for (final theme in ReadingTheme.values) {
    for (final scale in [1.0, 2.0]) {
      tafsirTest('lays out without overflow in ${theme.name} at '
          '${(scale * 100).round()}%', (tester, fixture) async {
        final model = await openModel(tester, fixture, at(fixture, 1, 2));
        await pumpScreen(
          tester,
          sheetOf(model),
          sheet: true,
          theme: theme,
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
      });
    }
  }

  tafsirTest('every control is labelled and at least 48', (
    tester,
    fixture,
  ) async {
    final handle = tester.ensureSemantics();
    final model = await openModel(tester, fixture, at(fixture, 2, 1));
    await pumpScreen(tester, sheetOf(model), sheet: true);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
