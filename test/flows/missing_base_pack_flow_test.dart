import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/ui/core/widgets/surah_list_item.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:holyquran/ui/features/index/views/index_screen.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';

import '../../testing/flows/flow_driver.dart';
import '../../testing/flows/flow_rig.dart';
import '../../testing/flows/flow_test_copy.dart';

// D-180: the test copy's pack absent from the phone, as the owner saw it. The
// pack is checked by the app's own integrity repository and read through
// DevicePackBundle from a folder that is not there; the pack is synthetic.

void _expectMissing() {
  expect(find.text(flowL10n.integrityBaseMissingTitle), findsOneWidget);
  expect(find.text(flowL10n.integrityBaseMissingBody), findsOneWidget);
  expect(find.text(flowL10n.integrityBaseTitle), findsNothing);
  expect(find.text(flowL10n.integrityBaseBody), findsNothing);
}

void main() {
  late Directory parent;
  setUp(() => parent = Directory.systemTemp.createTempSync('missing_pack'));
  tearDown(() => parent.deleteSync(recursive: true));

  Future<TestCopyPack> absent(WidgetTester tester, TestCopyPack pack) =>
      real(tester, () async {
        await pack.root.delete(recursive: true);
        return pack;
      });

  FlowRig().test('at the first start a missing pack is called missing, on '
      'home, the index and the reader, and no index is listed', (
    tester,
    run,
  ) async {
    final pack = await absent(
      tester,
      await real(tester, () => buildFlowTestCopy(parent)),
    );
    await run.session(
      tester,
      testCopy: pack,
      features: testCopyFeatures(pack),
      (session) async {
        expect(
          session.read<PackIntegrityRepository>().stateOf(pack.copy.pack.id),
          isA<IntegrityMissing>(),
        );
        expect(() => session.read<QuranTextRepository>(), throwsStateError);
        expect(find.byType(HomeScreen), findsOneWidget);
        _expectMissing();

        await tapNamed(tester, flowL10n.homeDoorIndex);
        expect(find.byType(IndexScreen), findsOneWidget);
        _expectMissing();
        expect(find.byType(SurahListItem), findsNothing);

        await tapNamed(tester, flowL10n.tabMushaf);
        expect(find.byType(MushafScreen), findsOneWidget);
        _expectMissing();
      },
    );
  });

  FlowRig().test('after a start that read the pack, a later start without it '
      'calls it missing', (tester, run) async {
    final pack = await real(tester, () => buildFlowTestCopy(parent));
    await run.session(
      tester,
      testCopy: pack,
      features: testCopyFeatures(pack),
      (session) async {
        expect(
          session.read<PackIntegrityRepository>().stateOf(pack.copy.pack.id),
          isA<IntegrityOk>(),
        );
        expect(find.text(flowL10n.integrityBaseMissingTitle), findsNothing);
        expect(find.text(flowL10n.integrityBaseTitle), findsNothing);
      },
    );

    await absent(tester, pack);
    await run.session(
      tester,
      testCopy: pack,
      features: testCopyFeatures(pack),
      (session) async {
        expect(find.byType(HomeScreen), findsOneWidget);
        _expectMissing();
      },
    );
  });
}
