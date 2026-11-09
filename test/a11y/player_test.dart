import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/widgets/seek_track.dart';
import 'package:holyquran/ui/features/listen/view_models/player_view_model.dart';
import 'package:holyquran/ui/features/listen/views/player_screen.dart';

import '../../testing/fakes/fake_player_repository.dart';
import '../../testing/fakes/fake_quran_index_repository.dart';
import 'a11y_support.dart';

// The full player, with a track that can be seeked (AX-09, NF-17: 2.1.1).

final _recitation = Recitation(
  id: 'synthetic-recitation',
  reciter: 'Synthetic reciter',
  riwaya: 'hafs',
  style: 'Synthetic style',
  unit: RecitationUnit.ayah,
  hasWordTiming: false,
  rightsComplete: true,
);

final _ayah = QuranAddress('hafs', 1, 2);

PlayerState _playing(Duration position) => PlayerState(
  plan: PlaybackPlan(
    recitation: _recitation,
    range: FromAyahTool(QuranAddress('hafs', 1, 1), AyahToolEnd.surah),
    repeat: RepeatMode.once,
    silence: Duration.zero,
    continuesToNextSurah: false,
    hasAyahBoundaries: true,
    segments: const [],
  ),
  segment: PlaybackSegment(
    kind: SegmentKind.ayah,
    address: _ayah,
    source: SurahClip(1, Duration.zero, const Duration(seconds: 10)),
    repeat: 1,
  ),
  segmentIndex: 0,
  ayah: _ayah,
  position: position,
  playing: true,
);

Future<FakePlayerRepository> _pump(
  WidgetTester tester,
  Size size,
  double textScale,
) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final player = FakePlayerRepository(
    state: _playing(const Duration(seconds: 5)),
  );
  final viewModel = PlayerViewModel(
    player: player,
    index: FakeQuranIndexRepository.synthetic(),
  );
  addTearDown(viewModel.dispose);
  final router = GoRouter(
    initialLocation: Routes.listen,
    routes: [
      GoRoute(
        path: Routes.listen,
        builder: (context, state) =>
            Scaffold(body: PlayerScreen(viewModel: viewModel)),
        routes: [
          GoRoute(
            path: RoutePaths.recitations,
            builder: (context, state) => const SizedBox.expand(),
          ),
        ],
      ),
      for (final sheet in [
        Routes.queueSheet,
        Routes.sleepSheet,
        Routes.repeatSheet,
        Routes.rangeSheet,
        Routes.silenceSheet,
      ])
        GoRoute(
          path: sheet,
          builder: (context, state) => const SizedBox.expand(),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: buildAppTheme(ReadingTheme.paper),
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return player;
}

void main() {
  for (final view in a11yViews) {
    testWidgets('the player is accessible: ${view.name}', (tester) async {
      addTearDown(tester.ensureSemantics().dispose);
      await _pump(tester, view.size, view.textScale);
      expect(find.byType(SeekTrack), findsOneWidget);
      await expectAccessible(tester);
    });
  }

  testWidgets('Tab reaches every control, the track with its ring', (
    tester,
  ) async {
    addTearDown(tester.ensureSemantics().dispose);
    await _pump(tester, phonePortrait, 1);
    await expectKeyboardReach(tester);
  });

  testWidgets('the arrow keys seek by the step, right to left', (tester) async {
    addTearDown(tester.ensureSemantics().dispose);
    final player = await _pump(tester, phonePortrait, 1);
    for (var i = 0; i < 30; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      if (FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<SeekTrack>() !=
          null) {
        break;
      }
    }
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<SeekTrack>(),
      isNotNull,
      reason: 'Tab reached no seek track',
    );
    expect(focusRingDrawn(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(player.commands, ['seek 10000', 'seek 5000']);
  });
}
