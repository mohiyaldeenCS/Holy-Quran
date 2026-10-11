import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/gallery/gallery_screen.dart';

import 'main.dart';
import 's1/s1_screen.dart';
import 's4/s4_screen.dart';
import 's4/s4_screen_test.dart' show FakeWidgetBridge, fakeS4Environment;
import 's4/widget_slots.dart';
import 's4/widget_test_pack.dart';
import 's5/s5_screen.dart';

// The launcher with the S3 screen, S1's storage and S4's widget plugin
// replaced, so that no test reaches the audio service, the network or the
// home-screen widget.

/// In the device session's order: S1, S7 (added after task G), S4, S3, S5.
const _entries = [
  'App',
  'Component gallery',
  'S1 surah rendering',
  'S4 home-screen widget',
  'S3 background audio',
  'S5 downloads',
];

/// Lets real file work finish between frames.
Future<void> _settleIo(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  late Directory root;
  late S1Environment environment;
  late Directory widgetRoot;
  late WidgetTestPack widgetPack;
  late FakeWidgetBridge bridge;

  setUpAll(() async {
    widgetRoot = await Directory.systemTemp.createTemp('spike_main_widget');
    widgetPack = await loadWidgetTestPack(widgetRoot);
  });
  tearDownAll(() async {
    widgetPack.close();
    await widgetRoot.delete(recursive: true);
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('spike_main');
    environment = S1Environment(
      prepare: () async => throw StateError('offline'),
      storage: () async => root,
      font: () async => throw StateError('no font'),
    );
    bridge = FakeWidgetBridge();
  });
  tearDown(() async {
    await bridge.close();
    await root.delete(recursive: true);
  });

  S4Environment s4Environment() =>
      fakeS4Environment(bridge: bridge, storage: root, pack: widgetPack);

  Widget spikeRoot({ColdStartLaunch? coldStart}) => SpikeRoot(
    s3Screen: (_) => const Scaffold(body: Text('S3 stand-in')),
    coldStart: coldStart,
    s1Environment: environment,
    s4Environment: s4Environment(),
  );

  QuranAddress ayah(int surah, int number) =>
      QuranAddress(widgetPack.ayat.first.address.riwaya, surah, number);

  testWidgets('the launcher lists the app, the gallery and the spikes in '
      'the session order, left to right', (tester) async {
    await tester.pumpWidget(spikeRoot());
    final tops = [
      for (final entry in _entries)
        tester.getTopLeft(find.widgetWithText(ListTile, entry)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(tops.toSet(), hasLength(_entries.length));
    expect(
      Directionality.of(tester.element(find.text('Spikes'))),
      TextDirection.ltr,
    );
    expect(find.byType(QuranApp), findsNothing);

    await tester.tap(find.text('S3 background audio'));
    await tester.pumpAndSettle();
    expect(find.text('S3 stand-in'), findsOneWidget);
  });

  testWidgets('without the media service the S3 entry says so and does not '
      'open, and the rest of the launcher works', (tester) async {
    await tester.pumpWidget(
      SpikeRoot(
        s3Screen: null,
        s3Unavailable: 'S3 unavailable: TimeoutException',
        s1Environment: environment,
        s4Environment: s4Environment(),
      ),
    );
    expect(find.text('S3 unavailable: TimeoutException'), findsOneWidget);
    await tester.tap(find.text('S3 background audio'));
    await tester.pumpAndSettle();
    expect(find.text('Spikes'), findsOneWidget);

    await tester.tap(find.text('App'));
    await tester.pumpAndSettle();
    expect(find.byType(QuranApp), findsOneWidget);
  });

  testWidgets('the gallery opens in Arabic, right to left', (tester) async {
    await tester.pumpWidget(spikeRoot());
    await tester.tap(find.text('Component gallery'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      Directionality.of(tester.element(find.byType(GalleryScreen))),
      TextDirection.rtl,
    );
  });

  testWidgets('"App" replaces the launcher with the app', (tester) async {
    await tester.pumpWidget(spikeRoot());
    await tester.tap(find.text('App'));
    await tester.pumpAndSettle();
    expect(find.byType(QuranApp), findsOneWidget);
    expect(find.text('Spikes'), findsNothing);
  });

  testWidgets('S1 opens with no pack', (tester) async {
    await tester.pumpWidget(spikeRoot());
    await tester.tap(find.text('S1 surah rendering'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await _settleIo(tester);
    expect(find.byType(S1Screen), findsOneWidget);
    expect(find.text('No pack yet.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('an armed cold start opens straight on S1, and back leads to '
      'the launcher', (tester) async {
    await tester.pumpWidget(
      spikeRoot(
        coldStart: ColdStartLaunch(arm: (surah: 2, ayah: 3), ages: {}),
      ),
    );
    expect(find.byType(S1ColdStartScreen), findsOneWidget);
    await _settleIo(tester);
    expect(find.textContaining('no prepared pack'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'S1 surah rendering'), findsOne);
  });

  testWidgets('S4 opens from the launcher and back leads to it', (
    tester,
  ) async {
    await tester.pumpWidget(spikeRoot());
    await tester.tap(find.text('S4 home-screen widget'));
    await tester.pump();
    await _settleIo(tester);
    expect(find.byType(S4Screen), findsOneWidget);
    expect(find.textContaining('Synthetic pack (noPack)'), findsOneWidget);
    expect(find.textContaining('Opened by a widget tap'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(S4Screen), findsNothing);
  });

  testWidgets('S5 opens from the launcher', (tester) async {
    await tester.pumpWidget(spikeRoot());
    await tester.tap(find.text('S5 downloads'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(S5Screen), findsOneWidget);
  });

  testWidgets('a widget tap that started the app opens S4 on its ayah, '
      'recorded as a cold start', (tester) async {
    final address = ayah(1, 2);
    bridge = FakeWidgetBridge(launchLink: widgetLink(address));
    await tester.pumpWidget(spikeRoot());
    await tester.pump();
    await _settleIo(tester);
    expect(find.byType(S4Screen), findsOneWidget);
    expect(
      find.text('Opened by a widget tap (cold start): $address'),
      findsOneWidget,
    );
    final results = File('${root.path}/s4-results.json').readAsStringSync();
    expect(results, contains('"address": "$address"'));
    expect(results, contains('"launch": "cold"'));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'S4 home-screen widget'), findsOne);
  });

  testWidgets('a widget tap while the app runs opens S4 on its ayah, '
      'recorded as a warm start', (tester) async {
    await tester.pumpWidget(spikeRoot());
    await tester.pump();
    final address = ayah(2, 3);
    bridge.links.add(widgetLink(address));
    await tester.pump();
    await _settleIo(tester);
    expect(
      find.text('Opened by a widget tap (warm start): $address'),
      findsOneWidget,
    );
    expect(
      File('${root.path}/s4-results.json').readAsStringSync(),
      contains('"launch": "warm"'),
    );
  });

  testWidgets('a foreign or malformed link opens nothing', (tester) async {
    bridge = FakeWidgetBridge(
      launchLink: Uri.parse('https://example.com/ayah?address=hafs:1:2'),
    );
    await tester.pumpWidget(spikeRoot());
    await tester.pump();
    for (final link in [
      Uri.parse('https://ayah?address=hafs:1:2'),
      Uri.parse('${WidgetLink.scheme}://ayah?address=not-an-address'),
      Uri.parse('${WidgetLink.scheme}://ayah?address=hafs:1:2:3'),
      Uri.parse('${WidgetLink.scheme}://other?address=hafs:1:2'),
      Uri.parse('${WidgetLink.scheme}://ayah'),
      null,
    ]) {
      bridge.links.add(link);
      await tester.pump();
    }
    await _settleIo(tester);
    expect(find.byType(S4Screen), findsNothing);
    expect(find.text('Spikes'), findsOneWidget);
    expect(File('${root.path}/s4-results.json').existsSync(), isFalse);
  });

  testWidgets('a widget tap after "App" replaced the launcher is ignored', (
    tester,
  ) async {
    await tester.pumpWidget(spikeRoot());
    await tester.tap(find.text('App'));
    await tester.pumpAndSettle();
    bridge.links.add(widgetLink(ayah(1, 1)));
    await tester.pumpAndSettle();
    expect(find.byType(QuranApp), findsOneWidget);
    expect(find.byType(S4Screen), findsNothing);
  });

  testWidgets('every launcher entry is at least 48 high, at 200% text too', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(spikeRoot());
    expect(tester.takeException(), isNull);
    for (final entry in _entries) {
      final size = tester.getSize(find.widgetWithText(ListTile, entry));
      expect(size.height, greaterThanOrEqualTo(48), reason: entry);
    }
  });
}
