import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';

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

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view
    ..physicalSize = const Size(412, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(theme: buildAppTheme(ReadingTheme.paper), home: home),
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
}
