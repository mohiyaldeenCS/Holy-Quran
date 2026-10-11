import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../../testing/packs/synthetic_pack.dart' show amiriQuranFontPath;
import '../s1/render/surah_text_block.dart';
import '../s1/render/synthetic_surah_pack.dart';
import '../s1/s1_screen.dart' show S1Environment;
import '../s1/text/spike_pack_writer.dart';
import 'ayah_toolbar_stand_in.dart';
import 'gesture_log.dart';
import 's7_record.dart';
import 's7_screen.dart';
import 's7_session.dart';
import 'synthetic_pages.dart';

// Every text is Arabic-script nonsense from the spike writer's synthetic
// pack; nothing here reaches the network.

S1Environment _environment(Directory root) => S1Environment(
  prepare: () => throw StateError('S7 never prepares'),
  storage: () async => Directory('${root.path}/storage'),
  font: () => File(amiriQuranFontPath).readAsBytes(),
);

/// Writes the synthetic pack and S1's note of where it is.
Future<void> _prepare(Directory root) async {
  final pack = await openSyntheticSpikePack(
    Directory('${root.path}/src'),
    withMarks: true,
  );
  pack.close();
  final storage = Directory('${root.path}/storage');
  await storage.create(recursive: true);
  await File('${storage.path}/s1-pack.json').writeAsString(
    jsonEncode({
      'directory': '${root.path}/src/$spikePackId/$spikePackVersion',
    }),
  );
}

Future<void> _pump(WidgetTester tester, Directory root) async {
  tester.view
    ..physicalSize = const Size(412, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(ReadingTheme.paper),
      home: S7Screen(environment: _environment(root)),
    ),
  );
}

/// Lets real file and database work finish between frames until [finder]
/// finds something.
Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 300; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('never found: $finder');
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('s7_screen');
  });
  tearDown(() => root.delete(recursive: true));

  test('the route name is the launcher\'s to use', () {
    expect(S7Screen.routeName, '/s7');
  });

  testWidgets('with no prepared pack, it says so and opens page mode only', (
    tester,
  ) async {
    await _pump(tester, root);
    await _until(tester, find.textContaining('No prepared pack'));
    expect(find.byType(SurahName), findsNothing);
    await tester.tap(find.text('Page mode only'));
    await tester.pumpAndSettle();
    expect(find.byType(SyntheticPages), findsOneWidget);
  });

  testWidgets('with the pack, it lists the surahs and opens one in the '
      'reader', (tester) async {
    await tester.runAsync(() => _prepare(root));
    await _pump(tester, root);
    await _until(tester, find.textContaining('Verified pack'));
    expect(find.byType(SurahName), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('surah $syntheticShortSurah')));
    await _until(tester, find.byType(SurahTextBlock));
    expect(
      find.descendant(
        of: find.byType(S7Session),
        matching: find.byType(SurahName),
      ),
      findsOneWidget,
      reason: 'the chrome',
    );
  });

  testWidgets('the panel exports the log next to S3\'s, overwriting it', (
    tester,
  ) async {
    await tester.runAsync(() => _prepare(root));
    await _pump(tester, root);
    await _until(tester, find.textContaining('Verified pack'));
    await tester.tap(find.byKey(const ValueKey('surah $syntheticShortSurah')));
    await _until(tester, find.byType(SurahTextBlock));
    await tester.pumpAndSettle();
    final block = tester.getRect(find.byType(SurahTextBlock));
    expect(block.bottom, greaterThan(120), reason: 'below the chrome');
    for (var i = 0; i < 2; i++) {
      await tester.tapAt(Offset(4, block.bottom - 4));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Debug'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Export log'));
    await tester.tap(find.text('Export log'));
    await _until(tester, find.textContaining('Saved '));

    final file = File('${root.path}/storage/s7-gestures.json');
    final bytes = await tester.runAsync(file.readAsBytes);
    final json = jsonDecode(utf8.decode(bytes!)) as Map<String, Object?>;
    expect(json['format'], 's7-gesture-log');
    expect(json['entries'], hasLength(2));
    expect(json, contains('toolbar_actions'));
    expect(json, contains('practice_by_rule'));
  });

  group('the log file', () {
    test('is ASCII with no Arabic code point, and is overwritten', () async {
      var now = 0;
      final record = S7Record(log: GestureLog(clockMs: () => now += 3))
        ..countAction(AyahToolbarAction.study);
      final storage = Directory('${root.path}/nested/spike');
      TestWidgetsFlutterBinding.ensureInitialized();
      record.log.record(
        gesture: LoggedGesture.tap,
        target: LoggedTarget.word,
        address: QuranAddress('hafs', 2, 255, 3),
        rule: 'priorityZonesWithSlop',
        textSize: 1.15,
        point: const Offset(12.5, 40),
        expectedTarget: LoggedTarget.word,
        expectedAddress: QuranAddress('hafs', 2, 255, 3),
      );
      final file = await exportS7Record(storage, record);
      expect(file.path, '${storage.path}/s7-gestures.json');
      final first = await file.readAsBytes();
      expect(first.every((b) => b < 0x80), isTrue);
      final json = jsonDecode(utf8.decode(first)) as Map<String, Object?>;
      expect(json['toolbar_actions'], {'study': 1});
      expect(json['practice_by_rule'], {
        'priorityZonesWithSlop': {'trials': 1, 'hits': 1},
      });

      record.log.record(gesture: LoggedGesture.pageZoom, page: 3, scale: 2);
      await exportS7Record(storage, record);
      final second =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      expect(second['entries'], hasLength(2));
    });
  });
}
