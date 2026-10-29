import 'package:flutter_test/flutter_test.dart';

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

void main() {
  final rig = FlowRig();

  rig.test('an ayah is played from home, set to repeat three times, and is '
      'heard exactly three times, then playback stops', (tester, run) async {
    final ayah = QuranAddress('hafs', 1, 2);

    await run.session(tester, (session) async {
      final player = session.read<PlayerRepository>();
      final engine = session.engine;

      // An earlier session stopped listening here.
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
      expect(player.state.playing, isTrue);
      expect(player.state.segment!.address, ayah);
      expect(engine.heard, isNotEmpty);

      // The player: its range chip opens the range, which is set to the one
      // ayah heard.
      await tapNamed(tester, flowL10n.tabListen);
      expect(find.byType(PlayerScreen), findsOneWidget);
      await tapNamedIn(
        tester,
        find.byType(PlayerScreen),
        flowL10n.playUntilStopped,
      );
      expect(find.byType(RangeSheet), findsOneWidget);
      await tapNamedIn(
        tester,
        find.byType(RangeSheet),
        flowL10n.playerPlay,
        done: () => player.state.plan!.range is SingleAyah,
      );
      expect(find.byType(RangeSheet), findsNothing);
      expect(player.state.plan!.repeat.count, 1);

      // Then the repeat, from one to three.
      await tapNamedIn(
        tester,
        find.byType(PlayerScreen),
        flowL10n.playerRepeat,
      );
      expect(find.byType(RepeatSheet), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tapNamedIn(
          tester,
          find.byType(RepeatSheet),
          flowL10n.stepperIncrease(flowL10n.playerRepeat),
        );
      }
      engine.heard.clear();
      await tapNamedIn(
        tester,
        find.byType(RepeatSheet),
        flowL10n.playerPlay,
        done: () => player.state.plan!.repeat.count == 3,
      );
      expect(find.byType(RepeatSheet), findsNothing);
      expect(player.state.plan!.repeat.count, 3);

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
}
