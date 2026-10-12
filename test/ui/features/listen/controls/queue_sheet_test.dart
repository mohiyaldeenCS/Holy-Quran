import 'package:flutter/material.dart' hide Icon, IconButton, RepeatMode;
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/features/listen/view_models/controls/queue_sheet_view_model.dart';

import '../../../../../testing/fakes/fake_player_repository.dart';
import 'controls_harness.dart';

void main() {
  final index = syntheticIndex();
  final builder = syntheticBuilder(index);
  final surah2 = planOf(builder, WholeSurah(2));
  final juz1 = planOf(builder, WholeJuz(1));
  final ayah = planOf(builder, FromAyahTool(at(1, 3), AyahToolEnd.page));
  final span = planOf(builder, PageSpan(1, 2));

  FakePlayerRepository queued(List<PlaybackPlan> queue) =>
      FakePlayerRepository(state: PlayerState(queue: queue));

  group('QueueSheetViewModel', () {
    test('moves and removes in the player, and tells its view', () {
      final player = queued([surah2, juz1, ayah]);
      final vm = QueueSheetViewModel(player: player, index: index);
      var told = 0;
      vm.addListener(() => told++);
      vm.move(0, 2);
      expect(vm.queue, [juz1, ayah, surah2]);
      vm.move(1, 1);
      vm.remove(0);
      expect(vm.queue, [ayah, surah2]);
      expect(told, 2);
      vm.dispose();
      player.removeFromQueue(0);
      expect(told, 2);
    });
  });

  group('QueueSheet', () {
    testWidgets('names each waiting plan under the queue title', (
      tester,
    ) async {
      final app = ControlsApp(
        player: queued([surah2, juz1, ayah, span]),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.queueSheet);

      expect(find.text(l10n.queueLabel), findsOneWidget);
      expect(find.text(l10n.surahTitle('Synthetic surah 2')), findsOneWidget);
      expect(find.text(l10n.juzLabel('١')), findsOneWidget);
      expect(
        find.text(l10n.surahAyahReference('Synthetic surah 1', '٣')),
        findsOneWidget,
      );
      expect(find.text(l10n.playToPageEnd), findsOneWidget);
      // A span of pages has no words for its end yet; only its reciter.
      expect(find.text('Synthetic reciter'), findsNWidgets(4));
      expect(find.byType(IconButton), findsNWidgets(4));
    });

    testWidgets('reorders the queue', (tester) async {
      final player = queued([surah2, juz1, ayah]);
      final app = ControlsApp(player: player, builder: builder, index: index);
      await app.open(tester, Routes.queueSheet);

      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(2, 0);
      await tester.pumpAndSettle();
      expect(player.state.queue, [ayah, surah2, juz1]);
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(0, 2);
      await tester.pumpAndSettle();
      expect(player.state.queue, [surah2, juz1, ayah]);
      final rows = find.descendant(
        of: find.byType(ReorderableListView),
        matching: find.byType(Text),
      );
      expect(
        tester.widget<Text>(rows.first).data,
        l10n.surahTitle('Synthetic surah 2'),
      );
    });

    testWidgets('offers the move actions to a screen reader', (tester) async {
      final player = queued([surah2, juz1]);
      final app = ControlsApp(player: player, builder: builder, index: index);
      await app.open(tester, Routes.queueSheet);

      SemanticsNode? row = tester.getSemantics(
        find.text(l10n.surahTitle('Synthetic surah 2')),
      );
      while (row != null &&
          (row.getSemanticsData().customSemanticsActionIds ?? []).isEmpty) {
        row = row.parent;
      }
      final actions = row!.getSemanticsData().customSemanticsActionIds!;
      expect(actions, isNotEmpty);
      row.owner!.performAction(
        row.id,
        SemanticsAction.customAction,
        actions.first,
      );
      await tester.pumpAndSettle();
      expect(player.state.queue, [juz1, surah2]);
    });

    testWidgets('removes the row whose button is tapped', (tester) async {
      final player = queued([surah2, juz1, ayah]);
      final app = ControlsApp(player: player, builder: builder, index: index);
      await app.open(tester, Routes.queueSheet);

      await tester.tap(find.byType(IconButton).at(1));
      await tester.pumpAndSettle();
      expect(player.state.queue, [surah2, ayah]);
      expect(find.text(l10n.juzLabel('١')), findsNothing);
      expect(find.bySemanticsLabel(l10n.resourceDelete), findsNWidgets(2));
    });

    testWidgets('stops listening to the player once closed', (tester) async {
      final player = queued([surah2, juz1]);
      final app = ControlsApp(player: player, builder: builder, index: index);
      await app.open(tester, Routes.queueSheet);
      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.sheetOpen, isFalse);
      player.removeFromQueue(0);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps a plan queued twice as two rows', (tester) async {
      final player = queued([surah2, surah2]);
      final app = ControlsApp(player: player, builder: builder, index: index);
      await app.open(tester, Routes.queueSheet);
      expect(find.text(l10n.surahTitle('Synthetic surah 2')), findsNWidgets(2));
    });

    testWidgets('fits at 200% text', (tester) async {
      final app = ControlsApp(
        player: queued([surah2, juz1, ayah]),
        builder: builder,
        index: index,
      );
      await app.open(tester, Routes.queueSheet, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
