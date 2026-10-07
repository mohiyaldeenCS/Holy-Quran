import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/gallery/gallery_screen.dart';

import 'main.dart';
import 's1/s1_screen.dart';

// The launcher with the S3 screen and S1's storage replaced, so that no
// test reaches the audio service, the network or path_provider.

const _entries = [
  'App',
  'Component gallery',
  'S1 surah rendering',
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

  setUp(() async {
    root = await Directory.systemTemp.createTemp('spike_main');
    environment = S1Environment(
      prepare: () async => throw StateError('offline'),
      storage: () async => root,
      font: () async => throw StateError('no font'),
    );
  });
  tearDown(() => root.delete(recursive: true));

  Widget spikeRoot({ColdStartLaunch? coldStart}) => SpikeRoot(
    s3Screen: (_) => const Scaffold(body: Text('S3 stand-in')),
    coldStart: coldStart,
    s1Environment: environment,
  );

  testWidgets('the launcher lists the app, the gallery and the spikes, left '
      'to right', (tester) async {
    await tester.pumpWidget(spikeRoot());
    for (final entry in _entries) {
      expect(find.widgetWithText(ListTile, entry), findsOneWidget);
    }
    expect(
      Directionality.of(tester.element(find.text('Spikes'))),
      TextDirection.ltr,
    );
    expect(find.byType(QuranApp), findsNothing);

    await tester.tap(find.text('S3 background audio'));
    await tester.pumpAndSettle();
    expect(find.text('S3 stand-in'), findsOneWidget);
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
}
