import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/routing/routes/home_routes.dart';
import 'package:holyquran/routing/routes/index_routes.dart';
import 'package:holyquran/routing/routes/listen_routes.dart';
import 'package:holyquran/routing/routes/more_routes.dart';
import 'package:holyquran/routing/routes/mushaf_routes.dart';
import 'package:holyquran/routing/routes/search_routes.dart';
import 'package:holyquran/routing/routes/study_routes.dart';
import 'package:holyquran/routing/routes/tafsir_routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/surah_list_item.dart';
import 'package:holyquran/ui/features/index/views/index_screen.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:holyquran/ui/features/search/views/search_screen.dart';
import 'package:holyquran/ui/features/tafsir/views/tafsir_reader_screen.dart';
import 'package:provider/provider.dart';

import '../../testing/fakes/fake_app_settings_repository.dart';
import '../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../testing/fakes/fake_quran_index_repository.dart';

// D-180: every screen that needs the text says why it has none, a missing
// base pack in its own words and a failed one in the failed words, and
// none shows an empty list in place of the alert.
final _l10n = lookupAppLocalizations(const Locale('ar'));
const _pack = (id: 'synthetic-base', version: 1);

Future<GoRouter> _pump(
  WidgetTester tester,
  PackIntegrityRepository? integrity, {
  ({String id, int version})? basePack = _pack,
  QuranIndexRepository? index,
}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = createRouter(
    features: [
      homeRoutesFor(basePack),
      mushafRoutesFor(basePack),
      indexRoutesFor(basePack),
      searchRoutesFor(basePack),
      listenRoutes,
      studyRoutesFor(basePack),
      tafsirRoutesFor(basePack),
      moreRoutes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsRepository>.value(
          value: FakeAppSettingsRepository(),
        ),
        if (integrity != null)
          ListenableProvider<PackIntegrityRepository>.value(value: integrity),
        if (index != null) ...[
          Provider<QuranIndexRepository>.value(value: index),
          Provider<QuranStructure>.value(value: index),
        ],
      ],
      child: QuranApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _go(WidgetTester tester, GoRouter router, String location) async {
  router.go(location);
  await tester.pumpAndSettle();
}

void _expectAlert({required bool missing}) {
  expect(find.byType(IntegrityAlert), findsOneWidget);
  final (shown, hidden) = missing
      ? (
          [_l10n.integrityBaseMissingTitle, _l10n.integrityBaseMissingBody],
          [_l10n.integrityBaseTitle, _l10n.integrityBaseBody],
        )
      : (
          [_l10n.integrityBaseTitle, _l10n.integrityBaseBody],
          [_l10n.integrityBaseMissingTitle, _l10n.integrityBaseMissingBody],
        );
  for (final text in shown) {
    expect(find.text(text), findsOneWidget);
  }
  for (final text in hidden) {
    expect(find.text(text), findsNothing);
  }
}

/// The tafsir reader, which says why it has no text in place of an empty
/// body.
void _expectTafsirAlert({required bool missing}) {
  expect(find.byType(TafsirReaderScreen), findsOneWidget);
  expect(find.text(_l10n.tafsirReaderTitle), findsOneWidget);
  _expectAlert(missing: missing);
}

Future<void> _openTafsirFromStudy(WidgetTester tester, GoRouter router) async {
  await _go(tester, router, Routes.study);
  await tester.tap(find.text(_l10n.tafsirReaderTitle));
  await tester.pumpAndSettle();
}

void _expectNoIndex() {
  expect(find.byType(SurahListItem), findsNothing);
  expect(find.byType(LevelSwitch), findsNothing);
}

void main() {
  group('a missing base pack at the first start, before anything reported '
      'it', () {
    testWidgets('home shows the missing alert', (tester) async {
      await _pump(tester, FakePackIntegrityRepository());

      _expectAlert(missing: true);
    });

    testWidgets('the index door leads to the missing alert, not an empty '
        'index', (tester) async {
      await _pump(tester, FakePackIntegrityRepository());

      await tester.tap(find.text(_l10n.homeDoorIndex));
      await tester.pumpAndSettle();

      expect(find.byType(IndexScreen), findsOneWidget);
      expect(find.text(_l10n.indexTitle), findsOneWidget);
      _expectAlert(missing: true);
      _expectNoIndex();
    });

    testWidgets('the reader shows the missing alert', (tester) async {
      final router = await _pump(tester, FakePackIntegrityRepository());
      await _go(tester, router, Routes.mushaf);

      expect(find.byType(MushafScreen), findsOneWidget);
      _expectAlert(missing: true);
    });

    testWidgets('search shows the missing alert', (tester) async {
      final router = await _pump(tester, FakePackIntegrityRepository());
      await _go(tester, router, Routes.search);

      expect(find.byType(SearchScreen), findsOneWidget);
      _expectAlert(missing: true);
    });

    testWidgets('the study tab leads to the tafsir reader, which shows the '
        'missing alert', (tester) async {
      final router = await _pump(tester, FakePackIntegrityRepository());
      await _openTafsirFromStudy(tester, router);

      expect(router.state.uri.path, Routes.studyTafsirAlert);
      _expectTafsirAlert(missing: true);
    });
  });

  group('a base pack reported missing', () {
    PackIntegrityRepository missing() =>
        FakePackIntegrityRepository({_pack.id: const IntegrityMissing()});

    for (final location in [
      Routes.mushafIndex,
      Routes.mushaf,
      Routes.search,
      Routes.studyTafsirAlert,
      Routes.studyTafsir(QuranAddress('hafs', 1, 1)),
    ]) {
      testWidgets('$location shows the missing alert', (tester) async {
        final router = await _pump(tester, missing());
        await _go(tester, router, location);

        _expectAlert(missing: true);
        _expectNoIndex();
      });
    }
  });

  group('a failed base pack', () {
    PackIntegrityRepository failed() => FakePackIntegrityRepository({
      _pack.id: const IntegrityFailed(PackInconsistent('synthetic', 'x')),
    });

    for (final location in [
      Routes.home,
      Routes.mushafIndex,
      Routes.mushaf,
      Routes.search,
      Routes.studyTafsirAlert,
    ]) {
      testWidgets('$location keeps the failed alert', (tester) async {
        final router = await _pump(tester, failed());
        await _go(tester, router, location);

        _expectAlert(missing: false);
        _expectNoIndex();
      });
    }

    testWidgets('the study tab leads to the tafsir reader, which shows the '
        'failed alert', (tester) async {
      final router = await _pump(tester, failed());
      await _openTafsirFromStudy(tester, router);

      _expectTafsirAlert(missing: false);
    });

    testWidgets('the tafsir reader at an ayah shows the failed alert', (
      tester,
    ) async {
      final router = await _pump(tester, failed());
      await _go(tester, router, Routes.studyTafsir(QuranAddress('hafs', 1, 1)));

      _expectTafsirAlert(missing: false);
    });

    testWidgets('the index shows the failed alert in place of its rows when '
        'the pack stops serving', (tester) async {
      final integrity = FakePackIntegrityRepository({
        _pack.id: const IntegrityOk(),
      });
      final index = FakeQuranIndexRepository.synthetic();
      final router = await _pump(tester, integrity, index: index);
      await _go(tester, router, Routes.mushafIndex);
      expect(find.byType(SurahListItem), findsWidgets);
      expect(find.byType(IntegrityAlert), findsNothing);

      index.surahs.clear();
      integrity.report(
        _pack.id,
        const IntegrityFailed(PackInconsistent('synthetic', 'x')),
      );
      await tester.pumpAndSettle();

      _expectAlert(missing: false);
      _expectNoIndex();
    });
  });

  testWidgets('a build that reads no base pack shows the index title alone', (
    tester,
  ) async {
    final router = await _pump(tester, null, basePack: null);
    await _go(tester, router, Routes.mushafIndex);

    expect(find.text(_l10n.indexTitle), findsOneWidget);
    expect(find.byType(IntegrityAlert), findsNothing);
    _expectNoIndex();
  });

  testWidgets('a build that reads no base pack has no tafsir entry', (
    tester,
  ) async {
    final router = await _pump(tester, null, basePack: null);
    await _go(tester, router, Routes.study);

    expect(find.text(_l10n.searchTitle), findsOneWidget);
    expect(find.text(_l10n.tafsirReaderTitle), findsNothing);
  });
}
