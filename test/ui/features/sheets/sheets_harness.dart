import 'dart:async';

import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/category_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/repositories/tafsir_repository.dart';
import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/mark_span.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/playback_plan_builder.dart';
import 'package:holyquran/domain/models/playback_range.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/domain/models/tafsir_book.dart';
import 'package:holyquran/domain/models/tafsir_position.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../testing/fakes/fake_category_repository.dart';
import '../../../../testing/fakes/fake_note_repository.dart';
import '../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../testing/fakes/fake_player_repository.dart';
import '../../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../../testing/fakes/fake_tag_repository.dart';
import '../listen/controls/controls_harness.dart'
    show planOf, playerAt, syntheticBuilder;
import '../tafsir/tafsir_fixture.dart';

/// A [QuranTextRepository] that serves what [inner] does until [failing] is
/// set, then fails every read as a pack that stopped serving does.
final class SwitchableText implements QuranTextRepository {
  SwitchableText(this.inner);

  final QuranTextRepository inner;
  bool failing = false;

  /// When set, the next [ayahText] decides its answer at once and gives it
  /// only when this completes, so that a later read can overtake it.
  Completer<void>? gate;

  Result<T> _fail<T>() => const Failure(PackDisabled('synthetic-text'));

  @override
  String get riwaya => inner.riwaya;

  @override
  PackFont get font => inner.font;

  @override
  Future<Result<List<SurahInfo>>> surahs() async =>
      failing ? _fail() : inner.surahs();

  @override
  Future<Result<PackText>> ayahText(QuranAddress address) async {
    final fail = failing;
    final held = gate;
    gate = null;
    if (held != null) await held.future;
    return fail ? _fail() : inner.ayahText(address);
  }

  @override
  Future<Result<PackText?>> basmala(int surah) async =>
      failing ? _fail() : inner.basmala(surah);

  @override
  Future<Result<Set<int>>> basmalaSurahs() async =>
      failing ? _fail() : inner.basmalaSurahs();

  @override
  Future<Result<List<WordSpan>>> words(QuranAddress address) async =>
      failing ? _fail() : inner.words(address);

  @override
  Future<Result<List<MarkSpan>>> marks(QuranAddress address) async =>
      failing ? _fail() : inner.marks(address);

  @override
  Future<Result<EditionMap>> editionMap() async =>
      failing ? _fail() : inner.editionMap();

  @override
  Future<Result<bool>> contains(QuranAddress address) async =>
      failing ? _fail() : inner.contains(address);
}

final sheetsL10n = lookupAppLocalizations(const Locale('ar'));

/// A phone tall enough for the whole of the ayah sheet at 100% text.
const tallPhone = Size(390, 1400);

/// The synthetic text pack and tafsir repositories of [TafsirFixture], with
/// the user's data, the player and the integrity of the packs held in
/// memory, as the app provides them. Every text in them is synthetic.
final class SheetsWorld {
  SheetsWorld(this.fixture)
    : index = FakeQuranIndexRepository.synthetic(),
      notes = FakeNoteRepository(),
      tags = FakeTagRepository(),
      categories = FakeCategoryRepository(),
      integrity = FakePackIntegrityRepository(),
      settings = FakeAppSettingsRepository() {
    builder = syntheticBuilder(index);
  }

  final TafsirFixture fixture;
  final FakeQuranIndexRepository index;
  final FakeNoteRepository notes;
  final FakeTagRepository tags;
  final FakeCategoryRepository categories;
  final FakePackIntegrityRepository integrity;
  final FakeAppSettingsRepository settings;
  late final PlaybackPlanBuilder builder;

  /// The text pack, which can be made to stop serving.
  late final text = SwitchableText(fixture.quran);

  /// A player holding a plan, as one that has played before.
  late FakePlayerRepository player = playerAt(planOf(builder, WholeSurah(1)));

  QuranAddress ayah(int surah, int ayah) =>
      QuranAddress(fixture.quran.riwaya, surah, ayah);

  QuranAddress word(int surah, int ayah, int word) =>
      QuranAddress(fixture.quran.riwaya, surah, ayah, word);

  /// The pack's text of [ayah], read in real time.
  Future<PackText> ayahText(WidgetTester tester, QuranAddress ayah) async =>
      switch (await tester.runAsync(() => fixture.quran.ayahText(ayah))) {
        Ok(:final value) => value,
        _ => throw TestFailure('$ayah is not in the synthetic pack'),
      };

  /// The offsets of word [number] of [ayah], read in real time.
  Future<WordSpan> wordSpan(
    WidgetTester tester,
    QuranAddress ayah,
    int number,
  ) async {
    final words = await tester.runAsync(() => fixture.quran.words(ayah));
    return switch (words) {
      Ok(:final value) => value.firstWhere((span) => span.number == number),
      _ => throw TestFailure('$ayah has no words'),
    };
  }

  Future<Note> note(QuranAddress at, String body) async =>
      (await notes.add(at, body) as Ok<Note>).value;
}

/// A test over a [SheetsWorld]. The fixture installs the default synthetic
/// tafsir unless [install] is false.
void sheetsTest(
  String name,
  Future<void> Function(WidgetTester tester, SheetsWorld world) body, {
  bool install = true,
}) => testWidgets(name, (tester) async {
  final fixture = (await tester.runAsync(
    () => TafsirFixture.open(install: install),
  ))!;
  final world = SheetsWorld(fixture);
  try {
    await body(tester, world);
  } finally {
    await tester.pumpWidget(const SizedBox());
    world.notes.dispose();
    world.tags.dispose();
    world.integrity.dispose();
    world.player.dispose();
    world.settings.dispose();
    await tester.runAsync(fixture.close);
  }
});

/// The app over [world], phone sized, at its home screen. Each of the text
/// pack, the tafsirs, the data of the user and the player is provided only
/// when asked for, as the composition root provides them.
Future<GoRouter> pumpSheetsApp(
  WidgetTester tester,
  SheetsWorld world, {
  bool text = true,
  bool tafsirs = true,
  bool userData = true,
  bool player = true,
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = tallPhone,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  world.settings.themePreference = ThemePreference(theme: theme);
  final router = createRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsRepository>.value(
          value: world.settings,
        ),
        if (text) Provider<QuranTextRepository>.value(value: world.text),
        Provider<QuranIndexRepository>.value(value: world.index),
        Provider<QuranStructure>.value(value: world.index),
        ListenableProvider<PackIntegrityRepository>.value(
          value: world.integrity,
        ),
        if (tafsirs)
          ListenableProvider<TafsirRepository>.value(
            value: world.fixture.tafsirs,
          ),
        if (userData) ...[
          ChangeNotifierProvider<NoteRepository>.value(value: world.notes),
          ChangeNotifierProvider<TagRepository>.value(value: world.tags),
          Provider<CategoryRepository>.value(value: world.categories),
        ],
        if (player) ...[
          ChangeNotifierProvider<PlayerRepository>.value(value: world.player),
          Provider<PlaybackPlanBuilder>.value(value: world.builder),
        ],
      ],
      child: QuranApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Pushes [location] from home and lets the reads it starts end, in real
/// time, until [until] is on the screen.
Future<void> openSheet(
  WidgetTester tester,
  GoRouter router,
  String location, {
  Finder? until,
}) async {
  unawaited(router.push(location));
  await tester.pumpAndSettle();
  for (var i = 0; i < 250; i++) {
    if (until == null || until.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

/// Lets reads that started meanwhile end, in real time.
Future<void> settleReads(WidgetTester tester, {Finder? until}) async {
  for (var i = 0; i < 250; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    if (until == null || until.evaluate().isNotEmpty) return;
  }
}

/// Waits in real time, for the packs' reads on other isolates, until [done].
Future<void> waitUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 500 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(done(), isTrue, reason: 'The reads did not end.');
}

/// How long, in real time, [done] takes to hold from now, polled each
/// millisecond.
Future<Duration> timeUntil(WidgetTester tester, bool Function() done) async {
  final watch = Stopwatch()..start();
  for (var i = 0; i < 2000 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  expect(done(), isTrue, reason: 'The reads did not end.');
  return watch.elapsed;
}

/// A [TafsirRepository] over [inner] whose next [positionAt] of [heldPack]
/// answers only when [gate] completes, so that a later read can overtake it.
final class GatedTafsirRepository implements TafsirRepository {
  GatedTafsirRepository(this.inner, {required this.heldPack});

  final TafsirRepository inner;
  final String heldPack;
  final gate = Completer<void>();
  var _held = false;

  @override
  void addListener(VoidCallback listener) => inner.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => inner.removeListener(listener);

  @override
  List<InstalledPack> get installed => inner.installed;

  @override
  String? get defaultTafsir => inner.defaultTafsir;

  @override
  Future<Result<void>> setDefaultTafsir(String packId) =>
      inner.setDefaultTafsir(packId);

  @override
  Future<Result<TafsirBook>> book(String packId) => inner.book(packId);

  @override
  Future<Result<TafsirPosition>> positionAt(
    String packId,
    QuranAddress ayah,
  ) async {
    final result = await inner.positionAt(packId, ayah);
    if (packId == heldPack && !_held) {
      _held = true;
      await gate.future;
    }
    return result;
  }
}
