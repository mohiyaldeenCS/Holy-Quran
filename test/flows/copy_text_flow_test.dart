import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/share/ayah_copy_text.dart';
import 'package:holyquran/ui/core/share/copy_sheet_view.dart';
import 'package:holyquran/ui/core/share/copy_sheet_view_model.dart';
import 'package:holyquran/ui/core/widgets/button.dart';

import '../../testing/flows/flow_driver.dart';
import '../../testing/flows/flow_rig.dart';
import '../../testing/golden.dart';
import '../integrity/pack_integrity_suite.dart';
import '../ui/core/share/share_test_pack.dart';
import 'copy_scenario.dart';

// SH-01, SH-05, NF-20: every ayah of the synthetic pack is copied through the
// app (copy_scenario.dart), and every ayah of a pack given with
// HOLYQURAN_PACK_DIR through the same sheet over that pack's repository.

void main() {
  FlowRig().test(
    'every ayah of the synthetic pack is copied, from the sheet of the app, as '
    'the pack stores it, and the toolbar leads to the same sheet',
    (tester, run) async {
      mockClipboard(tester);
      await copyEverySyntheticAyah(tester, run);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  const given = givenPackDirectory;
  if (given.isEmpty) {
    test(
      'every ayah of the pack given with HOLYQURAN_PACK_DIR is copied as the '
      'pack stores it',
      () {},
      skip: 'no --dart-define=HOLYQURAN_PACK_DIR=<pack-id/version> was given',
    );
  } else {
    testWidgets(
      'every ayah of the pack HOLYQURAN_PACK_DIR=$given is copied as the '
      'pack stores it',
      (tester) async {
        tester.view
          ..physicalSize = const Size(390, 1200)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        mockClipboard(tester);
        final pack = await real(tester, () => PackUnderTest.load(given));
        addTearDown(pack.close);
        final PackQuranTextRepository repository = pack.openRepository();
        final ayat = await real(tester, () => packAyat(pack, repository));
        expect(ayat, hasLength(pack.manifest.counts.ayat));
        final copyText = AyahCopyText(repository, flowL10n);

        final problems = await copyAll(ayat, (address) async {
          await clearClipboard(tester);
          await tester.pumpWidget(
            goldenApp(
              ReadingTheme.paper,
              CopySheetView(
                key: ValueKey(address),
                create: () => CopySheetViewModel(
                  address: address,
                  copyText: copyText,
                  copyToClipboard: const SystemClipboardService().copyText,
                ),
              ),
            ),
          );
          await tester.pump();
          // The sheet sits in a plain page here, with no route to hit-test.
          tester
              .widget<Button>(find.widgetWithText(Button, flowL10n.copyAction))
              .onPressed!();
          await tester.pump();
          return copiedText(tester);
        });
        expectNoProblems(problems);
      },
      timeout: const Timeout(Duration(minutes: 60)),
    );
  }
}
