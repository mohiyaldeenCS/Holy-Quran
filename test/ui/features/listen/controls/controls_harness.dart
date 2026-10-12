import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/playback_plan.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/repeat_mode.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes/listen_controls_routes.dart';
import 'package:holyquran/routing/routes/sheet_page.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../../../../testing/fakes/fake_player_repository.dart';
import '../../../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../../../testing/golden.dart';

final l10n = lookupAppLocalizations(const Locale('ar'));

/// The edition of [FakeQuranIndexRepository.synthetic]: three surahs of 4,
/// 3 and 1 ayat; surahs 2 and 3 have a separate basmala.
FakeQuranIndexRepository syntheticIndex() =>
    FakeQuranIndexRepository.synthetic();

PlaybackPlanBuilder syntheticBuilder(QuranIndexRepository index) =>
    PlaybackPlanBuilder(
      edition: EditionMap(
        edition: 'synthetic-edition',
        starts: {
          for (final division in [Division.page, Division.juz, Division.hizb])
            division: [
              for (var n = 1; n <= index.count(division); n++)
                index.firstAyah(division, n),
            ],
        },
        sajdas: const {},
      ),
      ayahCounts: [
        for (var surah = 1; surah <= index.surahCount; surah++)
          index.ayahCount(surah),
      ],
      basmalaSurahs: const {2, 3},
    );

Recitation syntheticRecitation({RecitationUnit unit = RecitationUnit.ayah}) =>
    Recitation(
      id: 'synthetic-${unit.name}',
      reciter: 'Synthetic reciter',
      riwaya: 'hafs',
      style: 'Synthetic style',
      unit: unit,
      hasWordTiming: false,
      rightsComplete: true,
    );

QuranAddress at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

PlaybackPlan planOf(
  PlaybackPlanBuilder builder,
  PlaybackRange range, {
  Recitation? recitation,
  RepeatMode repeat = RepeatMode.once,
  Duration silence = Duration.zero,
  bool continueToNextSurah = false,
}) =>
    (builder.build(
              recitation ?? syntheticRecitation(),
              range,
              repeat: repeat,
              silence: silence,
              continueToNextSurah: continueToNextSurah,
            )
            as PlanReady)
        .plan;

/// A player that has played [plan] and is at [ayah], segment [segment].
FakePlayerRepository playerAt(
  PlaybackPlan? plan, {
  QuranAddress? ayah,
  int? segment,
}) => FakePlayerRepository(
  state: PlayerState(plan: plan, ayah: ayah, segmentIndex: segment),
);

/// The app with the control sheets' routes over an empty home, its
/// dependencies provided; [open] pushes [location] from home.
final class ControlsApp {
  ControlsApp({
    required this.player,
    required this.builder,
    required this.index,
  });

  final PlayerRepository player;
  final PlaybackPlanBuilder builder;
  final QuranIndexRepository index;

  late final GoRouter router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox()),
      for (final sheet in listenControlsRoutes.sheets)
        GoRoute(
          path: sheet.path,
          pageBuilder: (context, state) => SheetPage<Object?>(
            key: state.pageKey,
            child: sheet.builder(context, state),
          ),
        ),
    ],
  );

  Future<void> open(
    WidgetTester tester,
    String location, {
    double textScale = 1,
    ReadingTheme theme = ReadingTheme.paper,
  }) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ListenableProvider<PlayerRepository>.value(value: player),
          Provider<PlaybackPlanBuilder>.value(value: builder),
          Provider<QuranIndexRepository>.value(value: index),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: buildAppTheme(theme),
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    unawaited(router.push(location));
    await tester.pumpAndSettle();
  }

  bool get sheetOpen => router.state.uri.path != '/';
}

/// [sheet] alone at the bottom of a phone-sized golden, in each theme.
Future<void> expectSheetGoldens(
  WidgetTester tester,
  String name,
  WidgetBuilder sheet,
) => expectGoldensInThemes(
  tester,
  name,
  (context) => Align(alignment: Alignment.bottomCenter, child: sheet(context)),
  surfaceSize: const Size(400, 520),
);
