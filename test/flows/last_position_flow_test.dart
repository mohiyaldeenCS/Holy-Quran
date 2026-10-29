import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:provider/provider.dart';

import '../../testing/flows/flow_driver.dart';
import '../../testing/flows/flow_rig.dart';

void main() {
  final rig = FlowRig();

  MushafViewModel reader(WidgetTester tester) =>
      tester.element(find.byType(MushafScreen)).read<MushafViewModel>();

  rig.test('the app opens at the ayah where the last session stopped reading '
      'when the user asked for it, and on home when he did not', (
    tester,
    run,
  ) async {
    late QuranAddress last;

    await run.session(tester, (session) async {
      await session.read<AppSettingsRepository>().setOpenAtLastPosition(true);
      expect(find.byType(HomeScreen), findsOneWidget);

      // Home, the index, the second juz: the reader opens in the middle of a
      // surah; then the user reads on.
      await tapNamed(tester, flowL10n.homeDoorIndex);
      await tapNamed(tester, flowL10n.indexTabJuz);
      await tapNamed(tester, RegExp(flowL10n.juzLabel(arabicDigits(2))));
      expect(find.byType(MushafScreen), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(reader(tester).position!.address.ayah, greaterThan(20));

      // Closing the app saves where reading stopped.
      pauseApp(tester);
      await settle(
        tester,
        () => session.read<ReadingPositionRepository>().last != null,
      );
      last = session.read<ReadingPositionRepository>().last!;
      expect(last.surah, 2);
      expect(last.ayah, greaterThan(20));
    });

    await run.session(tester, (session) async {
      expect(find.byType(HomeScreen), findsNothing);
      expect(reader(tester).position!.address, last);
    });

    await run.session(tester, (session) async {
      expect(find.byType(MushafScreen), findsOneWidget);
      await session.read<AppSettingsRepository>().setOpenAtLastPosition(false);
      await tester.pumpAndSettle();
    });
    await run.session(tester, (session) async {
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(MushafScreen), findsNothing);
      expect(session.read<ReadingPositionRepository>().last, last);
    });
  });
}
