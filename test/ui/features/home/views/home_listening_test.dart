import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/listening_position_repository.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/continue_card.dart';
import 'package:holyquran/ui/core/widgets/continue_listening_row.dart';
import 'package:holyquran/ui/core/widgets/home_door.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/features/home/view_models/home_view_model.dart';
import 'package:provider/provider.dart';

import '../../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../../testing/fakes/fake_player_repository.dart';
import '../../../../../testing/fakes/fake_reading_position_repository.dart';
import '../../listen/controls/controls_harness.dart' show syntheticRecitation;
import '../home_harness.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

QuranAddress _at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

Finder get _row => find.byType(ContinueListeningRow);

Finder get _play => find.descendant(
  of: _row,
  matching: find.bySemanticsLabel(_l10n.playerPlay),
);

void main() {
  group('the continue-listening row', () {
    testWidgets('shows the ayah and the reciter where listening stopped', (
      tester,
    ) async {
      await pumpHome(
        tester,
        last: syntheticAyah(),
        listened: listenedAt(_at(2, 2)),
        recitations: [listedRecitation()],
        player: FakePlayerRepository(),
      );

      final row = tester.widget<ContinueListeningRow>(_row);
      expect(row.ayah, 2);
      expect(row.reciter, syntheticRecitation().reciter);
      expect(find.text(_l10n.continueListeningLabel), findsOneWidget);
      expect(find.text(syntheticRecitation().reciter), findsOneWidget);
    });

    testWidgets('sits between the reading card and the doors', (tester) async {
      await pumpHome(
        tester,
        last: syntheticAyah(),
        listened: listenedAt(_at(2, 2)),
        recitations: [listedRecitation()],
        player: FakePlayerRepository(),
      );

      final card = tester.getRect(find.byType(ContinueCard));
      final row = tester.getRect(_row);
      final door = tester.getRect(find.byType(HomeDoor));
      expect(card.bottom, lessThan(row.top));
      expect(row.bottom, lessThan(door.top));
      expect(row.left, card.left);
      expect(row.right, card.right);
    });

    testWidgets('is hidden with no listening position', (tester) async {
      await pumpHome(
        tester,
        last: syntheticAyah(),
        recitations: [listedRecitation()],
        player: FakePlayerRepository(),
      );

      expect(_row, findsNothing);
      expect(find.text(_l10n.continueListeningLabel), findsNothing);
    });

    testWidgets('is hidden when the recitation is not listed', (tester) async {
      await pumpHome(
        tester,
        listened: listenedAt(_at(2, 2)),
        player: FakePlayerRepository(),
      );

      expect(_row, findsNothing);
    });

    testWidgets('is hidden without a player or without a verified pack', (
      tester,
    ) async {
      await pumpHome(
        tester,
        listened: listenedAt(_at(2, 2)),
        recitations: [listedRecitation()],
      );
      expect(_row, findsNothing);

      await pumpHome(
        tester,
        listened: listenedAt(_at(2, 2)),
        recitations: [listedRecitation()],
        player: FakePlayerRepository(),
        withIndex: false,
      );
      expect(_row, findsNothing);
    });

    testWidgets('is hidden for a position outside the pack', (tester) async {
      await pumpHome(
        tester,
        listened: listenedAt(_at(2, 9)),
        recitations: [listedRecitation()],
        player: FakePlayerRepository(),
      );

      expect(_row, findsNothing);
    });

    testWidgets('appears when a position is saved', (tester) async {
      await pumpHome(
        tester,
        listened: listenedAt(_at(2, 1)),
        recitations: [listedRecitation()],
        player: FakePlayerRepository(),
      );
      final positions = tester
          .element(find.byType(ContinueListeningRow))
          .read<ListeningPositionRepository>();

      await positions.save(listenedAt(_at(2, 3)));
      await tester.pump();

      expect(tester.widget<ContinueListeningRow>(_row).ayah, 3);
    });

    testWidgets('plays from the ayah, to the end of the mushaf', (
      tester,
    ) async {
      final player = FakePlayerRepository();
      await pumpHome(
        tester,
        listened: listenedAt(_at(1, 3)),
        recitations: [listedRecitation()],
        player: player,
      );

      await tester.tap(_play);
      await tester.pump();

      expect(player.commands, ['play 0']);
      final plan = player.state.plan!;
      expect(plan.recitation.id, syntheticRecitation().id);
      expect(plan.range, isA<FromAyahTool>());
      expect(plan.segments.first.address, _at(1, 3));
    });

    testWidgets('goes on at the offset within the ayah', (tester) async {
      final player = FakePlayerRepository();
      await pumpHome(
        tester,
        listened: listenedAt(_at(1, 3), offset: const Duration(seconds: 4)),
        recitations: [listedRecitation()],
        player: player,
      );

      await tester.tap(_play);
      await tester.pump();

      expect(player.commands, ['play 0', 'seek 4000']);
    });

    testWidgets('starts at the ayah when the reciter opens with an '
        'isti\'adha', (tester) async {
      final recitation = Recitation(
        id: 'synthetic-with-istiadha',
        reciter: 'Synthetic reciter',
        riwaya: 'hafs',
        style: 'Synthetic style',
        unit: RecitationUnit.ayah,
        hasWordTiming: false,
        rightsComplete: true,
        hasIstiadhaFile: true,
      );
      final player = FakePlayerRepository();
      await pumpHome(
        tester,
        listened: listenedAt(
          _at(1, 3),
          offset: const Duration(seconds: 2),
          recitation: recitation,
        ),
        recitations: [listedRecitation(recitation)],
        player: player,
      );

      await tester.tap(_play);
      await tester.pump();

      expect(player.commands, ['play 1', 'seek 2000']);
      expect(player.state.plan!.segments.first.kind, SegmentKind.istiadha);
    });

    testWidgets('plays on by whole surahs for a recitation without ayah '
        'timing', (tester) async {
      final recitation = syntheticRecitation(unit: RecitationUnit.surah);
      final player = FakePlayerRepository();
      await pumpHome(
        tester,
        listened: listenedAt(
          _at(2, 1),
          offset: const Duration(seconds: 30),
          recitation: recitation,
        ),
        recitations: [listedRecitation(recitation)],
        player: player,
      );

      await tester.tap(_play);
      await tester.pump();

      expect(player.commands, ['play 0', 'seek 30000']);
      expect(player.state.plan!.segments.first.kind, SegmentKind.surah);
      expect(player.state.plan!.segments.first.address, _at(2, 1));
    });

    testWidgets('plays the surah when the recitation cannot start inside it', (
      tester,
    ) async {
      final recitation = syntheticRecitation(unit: RecitationUnit.surah);
      final player = FakePlayerRepository();
      await pumpHome(
        tester,
        listened: listenedAt(_at(2, 2), recitation: recitation),
        recitations: [listedRecitation(recitation)],
        player: player,
      );

      await tester.tap(_play);
      await tester.pump();

      expect(player.commands, ['play 0']);
      expect(player.state.plan!.range, isA<WholeSurah>());
      expect(player.state.plan!.segments.first.address, _at(2, 1));
    });

    testWidgets('reports a player that refuses and stays', (tester) async {
      final player = FakePlayerRepository()..playFailure = Exception('refused');
      await pumpHome(
        tester,
        listened: listenedAt(_at(1, 3)),
        recitations: [listedRecitation()],
        player: player,
      );

      await tester.tap(_play);
      await tester.pump();

      expect(tester.takeException(), isException);
      expect(_row, findsOneWidget);
    });

    testWidgets('is labelled and reachable', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(
        tester,
        listened: listenedAt(_at(1, 3)),
        recitations: [listedRecitation()],
        player: FakePlayerRepository(),
      );

      expect(_play, findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    for (final theme in ReadingTheme.values) {
      testWidgets('lays out in ${theme.name} at 200%', (tester) async {
        await pumpHome(
          tester,
          last: syntheticAyah(),
          listened: listenedAt(_at(1, 3)),
          recitations: [listedRecitation()],
          player: FakePlayerRepository(),
          theme: theme,
          textScale: 2,
          size: const Size(360, 640),
        );

        await tester.scrollUntilVisible(_row, 100);
        expect(tester.takeException(), isNull);
        expect(_row, findsOneWidget);
      });
    }
  });

  group('the bookmarks door', () {
    testWidgets('is hidden until the bookmarks screen has a route', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text(_l10n.homeDoorBookmarks), findsNothing);
      expect(find.byType(HomeDoor), findsOneWidget);
    });

    testWidgets('opens the bookmarks, after the index door', (tester) async {
      final router = await pumpHome(tester, bookmarks: true);

      final doors = tester.widgetList<HomeDoor>(find.byType(HomeDoor));
      expect(doors.map((door) => door.label), [
        _l10n.homeDoorIndex,
        _l10n.homeDoorBookmarks,
      ]);
      expect(
        tester.getCenter(find.text(_l10n.homeDoorBookmarks)).dx,
        lessThan(tester.getCenter(find.text(_l10n.homeDoorIndex)).dx),
      );

      await tester.tap(find.text(_l10n.homeDoorBookmarks));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, Routes.bookmarks);
    });
  });

  group('when the base pack failed its check', () {
    final failed = FakePackIntegrityRepository({
      'base': const IntegrityFailed(PackInconsistent('base', 'synthetic')),
    });

    HomeViewModel model({String? basePackId = 'base'}) => HomeViewModel(
      positions: FakeReadingPositionRepository(last: syntheticAyah()),
      integrity: failed,
      basePackId: basePackId,
    );

    testWidgets('home shows the alert and no text of the pack', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHomeScreen(tester, model());

      expect(find.byType(IntegrityAlert), findsOneWidget);
      expect(find.text(_l10n.integrityBaseTitle), findsOneWidget);
      expect(find.text(_l10n.integrityBaseBody), findsOneWidget);
      expect(find.byType(ContinueCard), findsNothing);
      expect(_row, findsNothing);
      expect(find.text(_l10n.homeContinueHint), findsNothing);
      handle.dispose();
    });

    testWidgets('home shows no alert when the app bundles no base pack', (
      tester,
    ) async {
      await pumpHomeScreen(tester, model(basePackId: null));

      expect(find.byType(IntegrityAlert), findsNothing);
      expect(find.text(_l10n.homeContinueHint), findsOneWidget);
    });

    testWidgets('home shows no alert while the pack serves', (tester) async {
      await pumpHomeScreen(
        tester,
        HomeViewModel(
          integrity: FakePackIntegrityRepository({'base': const IntegrityOk()}),
          basePackId: 'base',
        ),
      );

      expect(find.byType(IntegrityAlert), findsNothing);
    });

    for (final theme in ReadingTheme.values) {
      testWidgets('the alert lays out in ${theme.name} at 200%', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpHomeScreen(tester, model(), theme: theme);

        expect(tester.takeException(), isNull);
        expect(find.byType(IntegrityAlert), findsOneWidget);
      });
    }
  });
}
