import 'package:flutter/material.dart' hide IconButton, RepeatMode;
import 'package:flutter/semantics.dart';
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
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart' as ds;
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/core/widgets/player_panel.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/features/listen/view_models/player_view_model.dart';
import 'package:holyquran/ui/features/listen/views/player_screen.dart';

import '../../../../testing/fakes/fake_player_repository.dart';
import '../../../../testing/fakes/fake_quran_index_repository.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

QuranAddress _at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

final _recitation = Recitation(
  id: 'synthetic-recitation',
  reciter: 'Synthetic reciter',
  riwaya: 'hafs',
  style: 'Synthetic style',
  unit: RecitationUnit.ayah,
  hasWordTiming: false,
  rightsComplete: true,
);

PlaybackPlan _plan({
  PlaybackRange? range,
  RepeatMode repeat = RepeatMode.once,
  Duration silence = Duration.zero,
  bool boundaries = true,
}) => PlaybackPlan(
  recitation: _recitation,
  range: range ?? FromAyahTool(_at(1, 1), AyahToolEnd.surah),
  repeat: repeat,
  silence: silence,
  continuesToNextSurah: false,
  hasAyahBoundaries: boundaries,
  segments: const [],
);

PlayerState _playing({
  PlaybackPlan? plan,
  PlaybackSource? source,
  Duration position = Duration.zero,
}) => PlayerState(
  plan: plan ?? _plan(),
  segment: PlaybackSegment(
    kind: SegmentKind.ayah,
    address: _at(1, 2),
    source: source ?? AyahFile(_at(1, 2)),
    repeat: 1,
  ),
  segmentIndex: 0,
  ayah: _at(1, 2),
  position: position,
  playing: true,
);

/// A ten-second clip of surah 1: the one kind of segment whose length the
/// player knows.
final _clip = SurahClip(1, Duration.zero, const Duration(seconds: 10));

const _sheets = [
  Routes.queueSheet,
  Routes.sleepSheet,
  Routes.repeatSheet,
  Routes.rangeSheet,
  Routes.silenceSheet,
];

GoRouter _router(PlayerViewModel? viewModel, List<String> sheets) => GoRouter(
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
    for (final sheet in sheets)
      GoRoute(
        path: sheet,
        builder: (context, state) => const SizedBox.expand(),
      ),
  ],
);

Future<GoRouter> _pump(
  WidgetTester tester,
  PlayerViewModel? viewModel, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = const Size(390, 844),
  List<String> sheets = _sheets,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = _router(viewModel, sheets);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: buildAppTheme(theme),
      themeAnimationStyle: AnimationStyle.noAnimation,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

({FakePlayerRepository player, PlayerViewModel viewModel}) _player([
  PlayerState state = PlayerState.idle,
]) {
  final player = FakePlayerRepository(state: state);
  final viewModel = PlayerViewModel(
    player: player,
    index: FakeQuranIndexRepository.synthetic(),
  );
  addTearDown(viewModel.dispose);
  return (player: player, viewModel: viewModel);
}

Finder _button(IconName icon) => find.byWidgetPredicate(
  (widget) => widget is PlayerButton && widget.icon == icon,
);

void main() {
  testWidgets('with no player, only the header and «تغيير» show', (
    tester,
  ) async {
    await _pump(tester, null);

    expect(find.text(_l10n.tabListen), findsOneWidget);
    // The queue is the player's: without one, its button would open a sheet
    // that throws.
    expect(find.byType(ds.IconButton), findsNothing);
    expect(find.text(_l10n.playerChange), findsOneWidget);
    expect(find.byType(PlayerPanel), findsNothing);
  });

  testWidgets('with a player, the queue button opens the queue', (
    tester,
  ) async {
    final router = await _pump(tester, _player().viewModel);

    expect(find.byType(ds.IconButton), findsOneWidget);
    await tester.tap(find.byType(ds.IconButton));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.queueSheet);
  });

  testWidgets('the sleep timer shows only once its route exists', (
    tester,
  ) async {
    await _pump(
      tester,
      _player(_playing()).viewModel,
      sheets: [
        for (final sheet in _sheets)
          if (sheet != Routes.sleepSheet) sheet,
      ],
    );

    expect(_button(IconName.night), findsNothing);
    expect(_button(IconName.repeat), findsOneWidget);
    expect(_button(IconName.previous), findsOneWidget);
    expect(_button(IconName.pause), findsOneWidget);
    expect(_button(IconName.next), findsOneWidget);
  });

  testWidgets('with its route, the sleep timer shows', (tester) async {
    await _pump(tester, _player(_playing()).viewModel);

    expect(_button(IconName.night), findsOneWidget);
  });

  testWidgets('before anything is played, the panel is hidden', (tester) async {
    await _pump(tester, _player().viewModel);

    expect(find.text(_l10n.playerChange), findsOneWidget);
    expect(find.byType(PlayerPanel), findsNothing);
  });

  testWidgets('shows the reciter, surah, ayah, page, range, repeat, speed '
      'and silence', (tester) async {
    final (:player, :viewModel) = _player(
      _playing(
        plan: _plan(
          repeat: RepeatMode(RepeatUnit.ayah, 3),
          silence: const Duration(seconds: 2),
        ),
      ),
    );
    await _pump(tester, viewModel);

    expect(find.text('Synthetic reciter'), findsOneWidget);
    expect(find.text('Synthetic style'), findsOneWidget);
    // The riwaya is an internal id, not a name to show.
    expect(find.textContaining('hafs'), findsNothing);
    expect(
      find.text(_l10n.surahAyahReference('Synthetic surah 1', arabicDigits(2))),
      findsOneWidget,
    );
    expect(find.text(_l10n.pageLabel(arabicDigits(1))), findsOneWidget);
    expect(
      find.text(_l10n.playerAyahOfTotal(arabicDigits(2), arabicDigits(4))),
      findsOneWidget,
    );
    expect(find.text(_l10n.playToSurahEnd), findsOneWidget);
    expect(
      find.text(_l10n.playerRepeatTimes(3, arabicDigits(3))),
      findsOneWidget,
    );
    expect(find.text('١٫٠×'), findsOneWidget);
    expect(find.text(_l10n.playerSilenceSeconds(arabicDigits(2))), findsOne);
    expect(
      tester.widget<PlayerButton>(_button(IconName.repeat)).count,
      3,
      reason: 'the repeat count is drawn on the repeat button',
    );
  });

  testWidgets('hides what the plan does not have', (tester) async {
    await _pump(tester, _player(_playing()).viewModel);

    expect(find.text(_l10n.playerRepeat), findsNothing);
    // An ayah file's length is not known, so there is no track to seek.
    expect(find.byType(ProgressBar), findsNothing);
  });

  testWidgets('a plan of whole surahs names no ayah', (tester) async {
    await _pump(
      tester,
      _player(_playing(plan: _plan(boundaries: false))).viewModel,
    );

    expect(find.text('Synthetic surah 1'), findsOneWidget);
    expect(
      find.text(_l10n.playerAyahOfTotal(arabicDigits(2), arabicDigits(4))),
      findsNothing,
    );
  });

  testWidgets('a new plan of whole surahs names its own surah, not the one '
      'last heard', (tester) async {
    final (:player, :viewModel) = _player(_playing());
    await _pump(tester, viewModel);
    expect(find.text('Synthetic surah 1'), findsNothing);
    expect(
      find.text(_l10n.surahAyahReference('Synthetic surah 1', arabicDigits(2))),
      findsOneWidget,
    );

    // The player keeps PlayerState.ayah of the last plan until the new one
    // reaches an ayah of its own, which a surah file never does.
    player.state = player.state.copyWith(
      plan: _plan(range: WholeSurah(3), boundaries: false),
      segment: PlaybackSegment(
        kind: SegmentKind.surah,
        address: _at(3, 1),
        source: const SurahFile(3),
        repeat: 1,
      ),
    );
    await tester.pump();

    expect(player.state.ayah, _at(1, 2));
    expect(find.text('Synthetic surah 3'), findsOneWidget);
    expect(find.textContaining('Synthetic surah 1'), findsNothing);
    expect(find.text(_l10n.pageLabel(arabicDigits(4))), findsOneWidget);
  });

  testWidgets('says when the connection failed, and only then', (tester) async {
    final (:player, :viewModel) = _player(_playing());
    await _pump(tester, viewModel);
    expect(find.text(_l10n.connectionFailed), findsNothing);

    player.state = player.state.copyWith(
      playing: false,
      error: () => PlayerError.connectionFailed,
    );
    await tester.pump();
    expect(find.text(_l10n.connectionFailed), findsOneWidget);

    // The other errors have no wording yet.
    player.state = player.state.copyWith(error: () => PlayerError.fileMissing);
    await tester.pump();
    expect(find.text(_l10n.connectionFailed), findsNothing);

    player.state = player.state.copyWith(error: () => null);
    await tester.pump();
    expect(find.text(_l10n.connectionFailed), findsNothing);
  });

  testWidgets('the connection failure is announced and readable in every '
      'theme', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final (:player, :viewModel) = _player(
        _playing().copyWith(error: () => PlayerError.connectionFailed),
      );
      for (final theme in ReadingTheme.values) {
        await _pump(tester, viewModel, theme: theme, textScale: 2);
        expect(tester.takeException(), isNull);
        expect(
          tester.getSemantics(find.text(_l10n.connectionFailed)),
          matchesSemantics(label: _l10n.connectionFailed, isLiveRegion: true),
        );
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('with nothing set, the range and silence chips still open '
      'their sheets', (tester) async {
    final router = await _pump(
      tester,
      _player(_playing(plan: _plan(range: WholeSurah(1)))).viewModel,
    );

    // The range has no end of the ayah tools to name, and there is no
    // silence: the chips say so, as they are the only way to their sheets.
    for (final label in [
      _l10n.playOnlyAyah,
      _l10n.playToPageEnd,
      _l10n.playToSurahEnd,
      _l10n.playToJuzEnd,
      _l10n.playUntilStopped,
    ]) {
      expect(find.text(label), findsNothing);
    }
    for (final (label, sheet) in [
      (_l10n.rangeSelectorTitle, Routes.rangeSheet),
      (_l10n.playerSilenceSeconds(arabicDigits(0)), Routes.silenceSheet),
    ]) {
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, sheet, reason: label);
      router.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the buttons call the player', (tester) async {
    final (:player, :viewModel) = _player(_playing());
    await _pump(tester, viewModel);

    await tester.tap(_button(IconName.pause));
    await tester.pump();
    await tester.tap(_button(IconName.play));
    await tester.tap(_button(IconName.next));
    await tester.tap(_button(IconName.previous));
    await tester.pump();

    expect(player.commands, ['pause', 'resume', 'nextAyah', 'previousAyah']);
  });

  testWidgets('the speed chip steps the speed and wraps around (AU-06)', (
    tester,
  ) async {
    final (:player, :viewModel) = _player(_playing());
    await _pump(tester, viewModel);

    await tester.tap(find.text('١٫٠×'));
    await tester.pump();
    expect(find.text('١٫٢٥×'), findsOneWidget);

    player.state = player.state.copyWith(speed: PlaybackSpeed.all.last);
    await tester.pump();
    expect(find.text('٢٫٠×'), findsOneWidget);
    await tester.tap(find.text('٢٫٠×'));
    await tester.pump();

    expect(player.commands, ['speed 1.25', 'speed 0.5']);
    expect(find.text('٠٫٥×'), findsOneWidget);
  });

  testWidgets('a chip answers taps across its whole 48 band', (tester) async {
    final (:player, :viewModel) = _player(_playing());
    await _pump(tester, viewModel);

    // The chip is drawn 36 high in the middle of the band: 21 above the
    // label's centre is outside the drawing, inside the band.
    final centre = tester.getCenter(find.text('١٫٠×'));
    await tester.tapAt(centre.translate(0, -21));
    await tester.pump();

    expect(player.commands, ['speed 1.25']);
  });

  testWidgets('tapping the track seeks from the right', (tester) async {
    final (:player, :viewModel) = _player(_playing(source: _clip));
    await _pump(tester, viewModel);

    final track = find.byType(ProgressBar);
    expect(track, findsOneWidget);
    final rect = tester.getRect(track);
    await tester.tapAt(Offset(rect.right - rect.width / 4, rect.center.dy));
    await tester.pump();
    await tester.tapAt(Offset(rect.left + rect.width / 4, rect.center.dy));
    await tester.pump();

    expect(player.commands, ['seek 2500', 'seek 7500']);
  });

  testWidgets('dragging the track seeks once, on release', (tester) async {
    final (:player, :viewModel) = _player(_playing(source: _clip));
    await _pump(tester, viewModel);

    final rect = tester.getRect(find.byType(ProgressBar));
    final gesture = await tester.startGesture(
      Offset(rect.right - rect.width / 10, rect.center.dy),
    );
    for (var step = 0; step < 5; step++) {
      await gesture.moveBy(Offset(-rect.width / 10, 0));
      await tester.pump();
    }
    expect(player.commands, isEmpty);
    await gesture.up();
    await tester.pump();

    // From a tenth in from the right, five tenths to the left: 0.6 of the
    // ten-second clip.
    expect(player.commands, ['seek 6000']);
  });

  testWidgets('a screen reader moves the track by steps', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final (:player, :viewModel) = _player(
        _playing(source: _clip, position: const Duration(seconds: 3)),
      );
      await _pump(tester, viewModel);

      final node = tester.getSemantics(
        find.bySemanticsLabel(_l10n.playerPosition),
      );
      // One node: the track's label and value with the two actions.
      final data = node.getSemanticsData();
      expect(data.label, _l10n.playerPosition);
      expect(data.value, _l10n.percentValue(arabicDigits(30)));
      final owner = node.owner!;
      owner.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      owner.performAction(node.id, SemanticsAction.decrease);
      owner.performAction(node.id, SemanticsAction.decrease);
      await tester.pump();

      player.state = player.state.copyWith(
        position: const Duration(seconds: 8),
      );
      owner.performAction(node.id, SemanticsAction.increase);
      await tester.pump();

      expect(player.commands, [
        'seek 8000',
        'seek 3000',
        'seek 0',
        'seek 10000',
      ]);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('«تغيير» opens the picker and the other buttons their sheets', (
    tester,
  ) async {
    final router = await _pump(tester, _player(_playing()).viewModel);

    await tester.tap(find.text(_l10n.playerChange));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.recitations);

    router.go(Routes.listen);
    await tester.pumpAndSettle();
    for (final (label, sheet) in [
      (_l10n.queueLabel, Routes.queueSheet),
      (_l10n.playerSleepTimer, Routes.sleepSheet),
      (_l10n.playerRepeat, Routes.repeatSheet),
      (_l10n.playToSurahEnd, Routes.rangeSheet),
    ]) {
      await tester.tap(find.bySemanticsLabel(label).first);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, sheet, reason: label);
      router.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('every control is labelled with a hit area of at least 48', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        _player(
          _playing(
            plan: _plan(
              repeat: RepeatMode(RepeatUnit.ayah, 3),
              silence: const Duration(seconds: 2),
            ),
            source: _clip,
          ),
        ).viewModel,
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });

  for (final theme in ReadingTheme.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('lays out without overflow in ${theme.name} at '
          '${(scale * 100).round()}% on 360 wide', (tester) async {
        await _pump(
          tester,
          _player(
            _playing(
              plan: _plan(
                repeat: RepeatMode(RepeatUnit.ayah, 3),
                silence: const Duration(seconds: 2),
              ),
              source: _clip,
            ),
          ).viewModel,
          theme: theme,
          textScale: scale,
          size: const Size(360, 740),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'matches the Screens2 player in the four themes',
    tags: 'golden',
    (tester) async {
      final viewModel = _player(
        _playing(
          plan: _plan(
            repeat: RepeatMode(RepeatUnit.ayah, 3),
            silence: const Duration(seconds: 2),
          ),
          source: _clip,
          position: const Duration(milliseconds: 3800),
        ),
      ).viewModel;
      for (final theme in ReadingTheme.values) {
        await _pump(tester, viewModel, theme: theme);
        await expectLater(
          find.byType(PlayerScreen),
          matchesGoldenFile('goldens/player_screen_${theme.name}.png'),
        );
      }
    },
  );
}
