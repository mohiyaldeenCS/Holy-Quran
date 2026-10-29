import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/domain/models/listening_position.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_rules.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/widgets/continue_listening_row.dart';
import 'package:holyquran/ui/features/listen/views/controls/range_sheet.dart';
import 'package:holyquran/ui/features/listen/views/controls/repeat_sheet.dart';
import 'package:holyquran/ui/features/listen/views/player_screen.dart';

import '../../testing/flows/flow_driver.dart';
import '../../testing/flows/flow_rig.dart';
import '../../testing/flows/flow_session.dart';

// AU-02, AU-04, AU-09, NF-20. The player's file locator is the stand-in of
// flow_session.dart, since the app's own (P1-13, P1-33) is not built yet.

void main() {
  final rig = FlowRig();
  final ayah = QuranAddress('hafs', 1, 2);

  // The user opens the resource manager, which fetches the catalogue that
  // lists the recitations, goes home, where the listening position of an
  // earlier session offers «أكمل الاستماع», and plays from there.
  Future<void> startFromHome(WidgetTester tester, FlowSession session) async {
    final player = session.read<PlayerRepository>();
    await tapNamed(tester, flowL10n.tabMore);
    await tapNamed(
      tester,
      flowL10n.resourceManagerTitle,
      done: () => session.read<CatalogueRepository>().catalogue != null,
    );
    await tapNamed(tester, flowL10n.tabHome);
    await session.read<ListeningPositionRepository>().save(
      ListeningPosition(
        address: ayah,
        recitationId: 'synthetic-listed',
        offset: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ContinueListeningRow), findsOneWidget);
    await tapNamedIn(
      tester,
      find.byType(ContinueListeningRow),
      flowL10n.playerPlay,
      done: () => player.state.playing,
    );
    expect(player.state.segment!.address, ayah);
    await tapNamed(tester, flowL10n.tabListen);
    expect(find.byType(PlayerScreen), findsOneWidget);
  }

  // The range chip opens the range, [pick] sets it, and the repeat goes from
  // one to three.
  Future<void> setRangeAndRepeat(
    WidgetTester tester,
    FlowSession session, {
    required Future<void> Function() pick,
    required bool Function(PlaybackRange range) isRange,
  }) async {
    final player = session.read<PlayerRepository>();
    await tapNamedIn(
      tester,
      find.byType(PlayerScreen),
      flowL10n.playUntilStopped,
    );
    expect(find.byType(RangeSheet), findsOneWidget);
    await pick();
    await tapNamedIn(
      tester,
      find.byType(RangeSheet),
      flowL10n.playerPlay,
      done: () => isRange(player.state.plan!.range),
    );
    expect(find.byType(RangeSheet), findsNothing);
    expect(player.state.plan!.repeat.count, 1);

    await tapNamedIn(tester, find.byType(PlayerScreen), flowL10n.playerRepeat);
    expect(find.byType(RepeatSheet), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tapNamedIn(
        tester,
        find.byType(RepeatSheet),
        flowL10n.stepperIncrease(flowL10n.playerRepeat),
      );
    }
    session.engine.heard.clear();
    await tapNamedIn(
      tester,
      find.byType(RepeatSheet),
      flowL10n.playerPlay,
      done: () => player.state.plan!.repeat.count == 3,
    );
    expect(find.byType(RepeatSheet), findsNothing);
    expect(player.state.plan!.repeat.count, 3);
  }

  rig.test('an ayah is played from home, set to repeat three times, and is '
      'heard exactly three times, then playback stops', (tester, run) async {
    await run.session(tester, (session) async {
      final player = session.read<PlayerRepository>();
      final engine = session.engine;
      await startFromHome(tester, session);
      await setRangeAndRepeat(
        tester,
        session,
        pick: () async {},
        isRange: (range) => range is SingleAyah,
      );

      // The device plays each file to its end; nothing else is ever played.
      final file = engine.playing!;
      expect(engine.heard, [file]);
      for (var heard = 1; heard < 3; heard++) {
        expect(player.state.playing, isTrue, reason: 'after $heard');
        engine.finish();
        await settle(tester);
        expect(engine.heard, hasLength(heard + 1));
      }
      expect(player.state.playing, isTrue);
      engine.finish();
      await settle(tester);

      expect(engine.heard, [file, file, file]);
      expect(player.state.playing, isFalse);
      expect(player.state.stopReason, StopReason.endOfPlan);
      expect(engine.playing, isNull);
    });
  });

  rig.test('a page is played from home, set to repeat three times, and every '
      'ayah of it is heard in order three times', (tester, run) async {
    await run.session(tester, (session) async {
      final player = session.read<PlayerRepository>();
      final engine = session.engine;
      await startFromHome(tester, session);
      await setRangeAndRepeat(
        tester,
        session,
        pick: () =>
            tapNamedIn(tester, find.byType(RangeSheet), flowL10n.goToPage),
        isRange: (range) => range is PageSpan,
      );

      // The first page of the synthetic pack ends with the fourth ayah of the
      // first surah.
      for (var round = 0; round < 40 && engine.playing != null; round++) {
        engine.finish();
        await settle(tester);
      }
      final ayat = [
        for (final name in engine.heard)
          if (name.startsWith('ayah-')) name,
      ];
      expect(ayat, [
        for (var pass = 0; pass < 3; pass++)
          for (var number = 1; number <= 4; number++) 'ayah-hafs-1-$number',
      ]);
      expect(player.state.playing, isFalse);
      expect(player.state.stopReason, StopReason.endOfPlan);
    });
  });
}
