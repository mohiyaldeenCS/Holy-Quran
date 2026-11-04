import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/routing/routes.dart';

import '../ui/features/sheets/sheets_harness.dart';
import 'a11y_support.dart';

// The sheets the screens open (AX-01, AX-02, AX-04, AX-09, NF-11, NF-18), in
// the app's own router, over the synthetic packs. The copy and share sheets,
// which need the clipboard and share services, are in `share_sheets_test.dart`;
// the go-to and context sheets, which need the index pack, in
// `index_sheets_test.dart`. The sleep timer and stop-after routes are not
// built yet.
void main() {
  QuranAddress ayah(SheetsWorld world) => world.ayah(1, 2);

  final sheets = <String, String Function(SheetsWorld world)>{
    'ayah': (world) => Routes.ayahSheet(ayah(world)),
    'word': (world) => Routes.wordSheet(world.word(1, 2, 3)),
    'tafsir': (world) => Routes.tafsirSheet(ayah(world)),
    'note': (world) => Routes.noteSheet(ayah(world)),
    'report': (world) => Routes.reportSheet(ayah(world)),
    'surah info': (world) => Routes.surahInfoSheet(1),
    'play options': (world) => Routes.playOptionsSheet(ayah(world)),
    'queue': (world) => Routes.queueSheet,
    'repeat': (world) => Routes.repeatSheet,
    'range': (world) => Routes.rangeSheet,
    'silence': (world) => Routes.silenceSheet,
  };

  for (final MapEntry(key: name, value: location) in sheets.entries) {
    for (final view in a11yViews) {
      sheetsTest('the $name sheet is accessible: ${view.name}', (
        tester,
        world,
      ) async {
        final handle = tester.ensureSemantics();
        final router = await pumpSheetsApp(
          tester,
          world,
          size: view.size,
          textScale: view.textScale,
        );
        await openSheet(
          tester,
          router,
          location(world),
          until: find.byType(BottomSheet),
        );
        for (var i = 0; i < 3; i++) {
          await settleReads(tester);
        }
        expect(find.byType(BottomSheet), findsOneWidget);
        await expectAccessible(tester);
        handle.dispose();
      });
    }

    sheetsTest('the $name sheet is reached by Tab', (tester, world) async {
      final handle = tester.ensureSemantics();
      final router = await pumpSheetsApp(tester, world, size: phonePortrait);
      await openSheet(
        tester,
        router,
        location(world),
        until: find.byType(BottomSheet),
      );
      for (var i = 0; i < 3; i++) {
        await settleReads(tester);
      }
      await expectKeyboardReach(tester);
      handle.dispose();
    });
  }
}
