import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';

import '../../testing/packs/synthetic_pack.dart' show amiriQuranFontPath;
import 'render/page_blocks_v2.dart';
import 'render/surah_list_v1.dart';
import 'render/surah_text_block.dart';
import 'render/synthetic_surah_pack.dart';
import 's1_screen.dart';
import 'text/spike_pack_writer.dart';

// Every text is Arabic-script nonsense from the spike writer's synthetic
// pack; nothing here reaches the network.

S1Environment _environment(Directory root) => S1Environment(
  prepare: () async {
    final pack = await openSyntheticSpikePack(Directory('${root.path}/src'));
    pack.close();
    return '${root.path}/src/$spikePackId/$spikePackVersion';
  },
  storage: () async => Directory('${root.path}/storage'),
  font: () => File(amiriQuranFontPath).readAsBytes(),
);

/// Large sizes scale less than small ones, as on Android 14.
final class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 14 ? fontSize * 2 : fontSize * 1.4;

  @override
  double get textScaleFactor => 2;

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = 2}) =>
      this;
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  TextScaler? system,
}) async {
  tester.view
    ..physicalSize = const Size(412, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(ReadingTheme.paper),
      builder: system == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: system),
              child: child!,
            ),
      home: home,
    ),
  );
}

/// Lets real file and database work finish between frames until [finder]
/// finds something.
Future<void> _until(
  WidgetTester tester,
  Finder finder, {
  bool absent = false,
}) async {
  for (var i = 0; i < 300; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (finder.evaluate().isEmpty == absent) return;
  }
  fail('never ${absent ? 'gone' : 'found'}: $finder');
}

/// Scrolls the screen's list until [finder] is built and visible.
Future<void> _show(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
}

/// Taps [finder] once the screen is no longer busy.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, find.byType(LinearProgressIndicator), absent: true);
  await _show(tester, finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _prepare(WidgetTester tester, Directory root) async {
  await _pump(tester, S1Screen(environment: _environment(root)));
  await _until(tester, find.text('No pack yet.'));
  await _tap(tester, find.text('Prepare text'));
  await _until(tester, find.textContaining('Verified pack'));
  await _until(tester, find.byType(LinearProgressIndicator), absent: true);
}

void main() {
  late Directory root;

  setUp(() async => root = await Directory.systemTemp.createTemp('s1_screen'));
  tearDown(() => root.delete(recursive: true));

  testWidgets('prepares the injected pack and lists every section', (
    tester,
  ) async {
    await _prepare(tester, root);
    expect(find.textContaining('2 surahs'), findsOneWidget);
    for (final label in [
      'Run integrity',
      'Pick a surah',
      'Run scroll test',
      'Arm and exit',
    ]) {
      await _show(tester, find.text(label));
      expect(find.text(label), findsOneWidget);
    }
    final armed = tester.widgetList<TextField>(find.byType(TextField));
    expect(armed.map((f) => f.controller!.text), [
      '$syntheticLongSurah',
      '${(syntheticLongAyat + 1) ~/ 2}',
    ]);
  });

  testWidgets('a failed prepare shows only its message', (tester) async {
    await _pump(
      tester,
      S1Screen(
        environment: S1Environment(
          prepare: () async => throw StateError('the server answered 404'),
          storage: () async => root,
          font: () => File(amiriQuranFontPath).readAsBytes(),
        ),
      ),
    );
    await _until(tester, find.text('No pack yet.'));
    await _tap(tester, find.text('Prepare text'));
    await _until(tester, find.text('the server answered 404'));
  });

  testWidgets('the reader shows the picked surah and highlights a tapped '
      'word, in V1 and V2', (tester) async {
    await _prepare(tester, root);
    await _tap(tester, find.text('Pick a surah'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('surah $syntheticShortSurah')), findsOne);
    await tester.tap(find.byKey(const ValueKey('surah $syntheticLongSurah')));
    await _until(tester, find.byType(SurahListV1));
    await tester.pumpAndSettle();

    final block = tester.renderObject<RenderSurahTextBlock>(
      find.byType(SurahTextBlock),
    );
    final first = block.paragraph.content.firstAyah;
    final word = QuranAddress(first.riwaya, first.surah, 2, 1);
    final origin = tester.getTopLeft(find.byType(SurahTextBlock));
    await tester.tapAt(origin + block.boxesOf(word).single.center);
    await tester.pump();
    expect(
      tester.widget<SurahTextBlock>(find.byType(SurahTextBlock)).highlighted,
      {word},
    );
    expect(find.textContaining('Tapped $word'), findsOneWidget);

    await tester.tap(find.text('2.0x'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('V2'));
    await tester.pumpAndSettle();
    expect(find.byType(PageBlocksV2), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widgetList<SurahTextBlock>(find.byType(SurahTextBlock))
          .first
          .highlighted,
      {word},
    );
  });

  testWidgets('a cold start opens the armed ayah and keeps the run', (
    tester,
  ) async {
    await _prepare(tester, root);
    const arm = (surah: syntheticLongSurah, ayah: 120);
    final ages = <String, Duration?>{'mainStart': null};
    await _pump(
      tester,
      S1ColdStartScreen(
        launch: ColdStartLaunch(arm: arm, ages: ages),
        environment: _environment(root),
      ),
    );
    await _until(tester, find.text('1 runs kept'));
    expect(find.textContaining('Disarm before using other screens'), findsOne);
    final runs = await tester.runAsync(
      () => File('${root.path}/storage/s1-cold-starts.json').readAsString(),
    );
    final run = (jsonDecode(runs!) as List<Object?>).single! as Map;
    expect(run['systemTextScale'], {'25px': 1.0, '14px': 1.0});
    expect(ages.keys, [
      'mainStart',
      'firstFrame',
      'packVerified',
      'surahRead',
      'laidOut',
      'savedAyahShown',
    ]);
    final block = tester.renderObject<RenderSurahTextBlock>(
      find.byType(SurahTextBlock),
    );
    final first = block.paragraph.content.firstAyah;
    final top = block.topOf(QuranAddress(first.riwaya, arm.surah, arm.ayah))!;
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(top, greaterThan(0));
    expect(scrollable.position.pixels, top);
  });

  testWidgets('the reader scrolls the marked surah to its end in V1 and V2', (
    tester,
  ) async {
    final read = (await tester.runAsync(
      () => readSyntheticSurahs(
        Directory('${root.path}/marked'),
        withMarks: true,
      ),
    ))!;
    read.pack.close();
    final surah = read.long;
    expect(surah.marks.expand((m) => m), isNotEmpty);
    await _pump(tester, S1ReaderScreen(surah: surah));
    await tester.pumpAndSettle();
    final last = surah.firstAyah.ayah + surah.ayat.length - 1;
    for (final layout in ['V1', 'V2']) {
      if (layout == 'V2') {
        await tester.tap(find.text('V2'));
        await tester.pumpAndSettle();
        expect(find.byType(PageBlocksV2), findsOneWidget);
      }
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position;
      while (position.pixels < position.maxScrollExtent) {
        position.jumpTo(
          math.min(position.pixels + 2000, position.maxScrollExtent),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: layout);
      }
      expect(
        find.byWidgetPredicate((w) => w is AyahMarker && w.number == last),
        findsOneWidget,
        reason: '$layout reaches ayah $last',
      );
    }
  });

  testWidgets('the reader labels the system scale at the Quran size and at '
      '14 px, which differ under non-linear scaling', (tester) async {
    final surah = (await tester.runAsync(
      () => readSyntheticSurahs(Directory('${root.path}/src')),
    ))!;
    surah.pack.close();
    await _pump(
      tester,
      S1ReaderScreen(surah: surah.short),
      system: const _NonlinearScaler(),
    );
    await tester.pumpAndSettle();
    expect(find.text('System 1.40x at 25 px, 2.00x at 14 px'), findsOneWidget);
    expect(find.text('2.0x'), findsOneWidget);
  });
}
