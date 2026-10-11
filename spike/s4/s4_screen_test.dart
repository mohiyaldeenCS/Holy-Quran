import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';

import '../../testing/packs/synthetic_pack.dart';
import 'ayah_widget_face.dart';
import 'native_shaping_probe.dart';
import 's4_screen.dart';
import 'shaping_compare.dart';
import 'widget_bridge.dart';
import 'widget_fit.dart';
import 'widget_publisher.dart';
import 'widget_slots.dart';
import 'widget_test_pack.dart';

// The S4 screen with a fake bridge, a fake probe and a fake renderer, on the
// synthetic widget pack: no plugin, no network, no path_provider. The
// launcher's tests use the same fakes.

/// A bridge that records each call; [failing] names a call that throws, and
/// [links] are the taps, parsed by the real link parser.
final class FakeWidgetBridge implements WidgetBridge {
  FakeWidgetBridge({this.failing, this.pinAnswer = true, this.launchLink});

  final String? failing;
  final bool pinAnswer;
  final Uri? launchLink;
  final calls = <String>[];
  final links = StreamController<Uri?>.broadcast();

  Future<void> close() => links.close();

  void _record(String call) {
    calls.add(call);
    if (call == failing) throw const WidgetBridgeException('fake', false);
  }

  @override
  Future<String> savePng(String key, Uint8List png) async {
    _record('savePng');
    return '/data/ayah_widget/$key.png';
  }

  @override
  Future<void> saveString(String key, String value) async =>
      _record('saveString');

  @override
  Future<void> scheduleUpdates(List<DateTime> times) async =>
      _record('scheduleUpdates');

  @override
  Future<void> update() async => _record('update');

  @override
  Future<bool> requestPin() async {
    _record('requestPin');
    return pinAnswer;
  }

  @override
  Future<QuranAddress?> launchAddress() async =>
      addressFromWidgetLink(launchLink);

  @override
  Stream<QuranAddress?> get taps => links.stream.map(addressFromWidgetLink);
}

/// Flutter's own layout moved by fixed deltas, with a set font digest.
final class FakeShapingProbe implements ShapingProbe {
  FakeShapingProbe(this.fontSha256);

  static const widthDelta = 1.5;
  static const heightDelta = 2.0;

  final String fontSha256;

  @override
  Future<({ShapingMeasure measure, String fontSha256})> measure(
    ShapingSample sample, {
    required double fontSize,
    required double maxWidth,
  }) async {
    final flutter = measureFlutterShaping(
      sample,
      fontSize: fontSize,
      maxWidth: maxWidth,
    );
    return (
      measure: (
        width: flutter.width + widthDelta,
        height: flutter.height + heightDelta,
        lineCount: flutter.lineCount,
        lineStarts: flutter.lineStarts,
        lineWidths: [for (final w in flutter.lineWidths) w + widthDelta],
      ),
      fontSha256: fontSha256,
    );
  }
}

/// Bytes standing in for the bundled font, and their digest.
final fakeFont = Uint8List.fromList([1, 2, 3, 4]);
final fakeFontSha256 = sha256.convert(fakeFont).toString();

final _renderRatios = <double>[];

Future<Uint8List> _fakeRender(AyahWidgetFace face, double pixelRatio) async {
  _renderRatios.add(pixelRatio);
  return Uint8List(face.look == WidgetLook.paper ? 3 : 5)
    ..[0] = _renderRatios.length;
}

/// An S4 environment over [bridge] whose fallback is [pack], kept open
/// across tests, and whose files go to [storage].
S4Environment fakeS4Environment({
  required WidgetBridge bridge,
  required Directory storage,
  required WidgetTestPack pack,
  ShapingProbe? probe,
  String? packDirectory,
  String pinnedPackSha256 = '',
}) => S4Environment(
  bridge: () async => bridge,
  probe: probe ?? FakeShapingProbe(fakeFontSha256),
  storage: () async => storage,
  packDirectory: () async => packDirectory,
  synthetic: () async =>
      (ayat: pack.ayat, textSha256: pack.textSha256, close: () {}),
  font: () async => fakeFont,
  pinnedPackSha256: pinnedPackSha256,
  render: _fakeRender,
  now: () => DateTime(2026, 10, 11, 15, 30),
);

/// Lets real file and database work finish between frames, until no busy
/// bar is left or [limit] has passed.
Future<void> settleIo(
  WidgetTester tester, {
  Duration limit = const Duration(seconds: 10),
}) async {
  final clock = Stopwatch()..start();
  do {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  } while (find.byType(LinearProgressIndicator).evaluate().isNotEmpty &&
      clock.elapsed < limit);
}

bool _isArabic(int rune) =>
    (rune >= 0x0600 && rune <= 0x06FF) ||
    (rune >= 0x0750 && rune <= 0x077F) ||
    (rune >= 0x08A0 && rune <= 0x08FF) ||
    (rune >= 0xFB50 && rune <= 0xFDFF) ||
    (rune >= 0xFE70 && rune <= 0xFEFF);

/// Paper and night of each face, at its logical size whatever the text
/// scale.
void expectFaces(WidgetTester tester) {
  final faces = find.byType(AyahWidgetFace);
  expect(faces, findsNWidgets(4));
  final sizes = [
    for (final element in faces.evaluate())
      (
        (element.widget as AyahWidgetFace).look,
        tester.getSize(find.byWidget(element.widget)),
      ),
  ];
  expect(sizes, [
    for (final size in WidgetFaceSize.values)
      for (final look in WidgetLook.values) (look, faceSizeOf(size)),
  ]);
}

/// Every text painted outside the face previews.
Iterable<String> chromeTexts(WidgetTester tester) {
  final inFaces = find
      .descendant(
        of: find.byType(AyahWidgetFace),
        matching: find.byType(RichText),
      )
      .evaluate()
      .toSet();
  return find
      .byType(RichText)
      .evaluate()
      .where((element) => !inFaces.contains(element))
      .map((element) => (element.widget as RichText).text.toPlainText());
}

/// Short ayat under the widget pack's synthetic names, in the shapes the
/// default divisions and sajdas need.
final _deviceSurahs = [
  for (final (name, count) in [
    (widgetTestSurahNames[0], 4),
    (widgetTestSurahNames[1], 3),
    (widgetTestSurahNames[2], 1),
  ])
    SyntheticSurah(
      name: name,
      ayat: List.filled(count, const SyntheticAyah(widgetTestPhrase)),
    ),
];

void main() {
  late Directory root;
  late Directory storage;
  late WidgetTestPack pack;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('s4_screen');
    pack = await loadWidgetTestPack(Directory('${root.path}/widget'));
  });
  tearDownAll(() async {
    pack.close();
    await root.delete(recursive: true);
  });

  setUp(() async {
    storage = await Directory.systemTemp.createTemp('s4_storage');
    _renderRatios.clear();
  });
  tearDown(() => storage.delete(recursive: true));

  Future<FakeWidgetBridge> open(
    WidgetTester tester, {
    FakeWidgetBridge? bridge,
    ShapingProbe? probe,
    String? packDirectory,
    String pinnedPackSha256 = '',
  }) async {
    final fake = bridge ?? FakeWidgetBridge();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(ReadingTheme.paper),
        home: S4Screen(
          environment: fakeS4Environment(
            bridge: fake,
            storage: storage,
            pack: pack,
            probe: probe,
            packDirectory: packDirectory,
            pinnedPackSha256: pinnedPackSha256,
          ),
        ),
      ),
    );
    await settleIo(tester);
    return fake;
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    // A focused field scrolls itself into view with an animation.
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find.text(label),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pump();
    await settleIo(tester);
  }

  Map<String, Object?> results() =>
      jsonDecode(File('${storage.path}/s4-results.json').readAsStringSync())
          as Map<String, Object?>;

  /// What the publisher takes for [size] from the synthetic pack: the
  /// candidates that fit, at most seven.
  ({int slots, List<String> skipped}) expected(WidgetFaceSize size) {
    final box = AyahWidgetFace.ayahBoxOf(faceSizeOf(size));
    var slots = 0;
    final skipped = <String>[];
    for (final ayah in pack.ayat) {
      if (slots == 7) break;
      if (fitQuranSize(ayah.ayah, box) == null) {
        skipped.add(ayah.address.toString());
      } else {
        slots++;
      }
    }
    return (slots: slots, skipped: skipped);
  }

  testWidgets('with no device pack it uses the synthetic pack and says why', (
    tester,
  ) async {
    await open(tester);
    expect(find.textContaining('Synthetic pack (noPack)'), findsOneWidget);
    expect(find.textContaining(pack.textSha256), findsOneWidget);
  });

  testWidgets('publish shows per face the slots made, the ayat skipped and '
      'the render time, at the device pixel ratio', (tester) async {
    final bridge = await open(tester);
    await tapButton(tester, 'Publish');

    expect(tester.takeException(), isNull);
    for (final size in WidgetFaceSize.values) {
      final want = expected(size);
      expect(want.skipped, isNotEmpty, reason: 'the pack has long ayat');
      expect(
        find.textContaining(
          '${size.name}: ${want.slots} slots, ${want.skipped.length} skipped, '
          'render ',
        ),
        findsOneWidget,
      );
      final face = (results()['publishes']! as List<Object?>).single;
      final faces = (face! as Map<String, Object?>)['faces']!;
      final stored = (faces as Map<String, Object?>)[size.name]!;
      expect((stored as Map<String, Object?>)['skipped'], want.skipped);
    }
    expect(_renderRatios, isNotEmpty);
    expect(_renderRatios.toSet(), {tester.view.devicePixelRatio});
    expect(bridge.calls.last, 'update');
    // Paper and night, both sizes: the faces the widget shows first.
    expectFaces(tester);
  });

  testWidgets('the faces open one per page at the safe area origin', (
    tester,
  ) async {
    await open(tester);
    await tapButton(tester, 'Publish');
    await tapButton(tester, 'Compare at whole pixels');
    await tester.pumpAndSettle();
    final face = find.byType(AyahWidgetFace);
    expect(face, findsOneWidget);
    expect(tester.getTopLeft(face), Offset.zero);
    expect(tester.getSize(face), faceSizeOf(WidgetFaceSize.medium));
    expect(find.textContaining('medium paper'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.textContaining('medium night'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(AyahWidgetFace)), Offset.zero);
  });

  testWidgets('the start filters the candidates', (tester) async {
    await open(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Start surah'), '2');
    await tester.enterText(find.widgetWithText(TextField, 'Start ayah'), '2');
    await tapButton(tester, 'Publish');
    final run =
        (results()['publishes']! as List<Object?>).single!
            as Map<String, Object?>;
    final riwaya = pack.ayat.first.address.riwaya;
    expect(run['start'], '$riwaya:2:2');
    expect(run['candidates'], 3);
  });

  testWidgets('a failed publish shows the call that failed', (tester) async {
    await open(tester, bridge: FakeWidgetBridge(failing: 'savePng'));
    await tapButton(tester, 'Publish');
    expect(
      find.textContaining(
        'Failed at savePng(ayah_widget_medium_0_paper): '
        'WidgetBridgeException',
      ),
      findsOneWidget,
    );
    expect(find.byType(AyahWidgetFace), findsNothing);
    final run =
        (results()['publishes']! as List<Object?>).single!
            as Map<String, Object?>;
    expect(run['result'], 'failure');
    expect(run['failedCall'], 'savePng(ayah_widget_medium_0_paper)');
  });

  testWidgets('pin shows its result', (tester) async {
    await open(tester);
    await tapButton(tester, 'Pin the widget');
    expect(find.textContaining('Pin requested at'), findsOneWidget);
  });

  testWidgets('a launcher that cannot pin says so', (tester) async {
    await open(tester, bridge: FakeWidgetBridge(pinAnswer: false));
    await tapButton(tester, 'Pin the widget');
    expect(find.textContaining('cannot pin widgets'), findsOneWidget);
    final pin =
        (results()['pins']! as List<Object?>).single! as Map<String, Object?>;
    expect(pin['supported'], isFalse);
  });

  testWidgets('the probe shows the native minus Flutter deltas and whether '
      'the fonts match', (tester) async {
    await open(tester);
    await tapButton(tester, 'Run the probe');
    for (final sample in ShapingSample.values) {
      expect(
        find.text(
          '${sample.name}: width 1.50, height 2.00, lines 0, first moved '
          'line none, font matches',
        ),
        findsOneWidget,
      );
    }
    final shaping =
        (results()['shaping']! as List<Object?>).single!
            as Map<String, Object?>;
    expect(shaping['assetFontSha256'], fakeFontSha256);
    expect(shaping['samples'], hasLength(ShapingSample.values.length));
  });

  testWidgets('a probe whose font differs says so', (tester) async {
    await open(tester, probe: FakeShapingProbe('0' * 64));
    await tapButton(tester, 'Run the probe');
    expect(find.textContaining('font differs'), findsNWidgets(4));
  });

  testWidgets('the results file is ASCII and holds no Arabic code point', (
    tester,
  ) async {
    await open(tester);
    await tapButton(tester, 'Publish');
    await tapButton(tester, 'Pin the widget');
    await tapButton(tester, 'Run the probe');
    final raw = File('${storage.path}/s4-results.json').readAsStringSync();
    expect(raw.codeUnits.where((unit) => unit > 0x7f), isEmpty);
    expect(raw.runes.where(_isArabic), isEmpty);
    expect(results(), containsPair('spike', 'S4'));
    expect(results().keys, containsAll(['publishes', 'pins', 'shaping']));
    expect(raw, isNot(contains('/data/ayah_widget')));
  });

  test('the results encoder refuses a non-ASCII character', () {
    expect(() => encodeS4Results({'x': '\u{646}'}), throwsStateError);
  });

  testWidgets('a pinned device pack is used, and a wrong pin falls back to '
      'the synthetic pack', (tester) async {
    final built = (await tester.runAsync(
      () => buildSyntheticPack(
        Directory('${root.path}/device'),
        surahs: _deviceSurahs,
      ),
    ))!;
    final sha = sha256.convert(built.textFile.readAsBytesSync()).toString();
    await open(
      tester,
      packDirectory: built.directory.path,
      pinnedPackSha256: sha,
    );
    expect(find.text('Device pack, text.sqlite $sha'), findsOneWidget);
    await tapButton(tester, 'Publish');
    final run =
        (results()['publishes']! as List<Object?>).single!
            as Map<String, Object?>;
    expect(run['pack'], 'device');
    expect(run['packTextSha256'], sha);

    await tester.pumpWidget(const SizedBox());
    await open(
      tester,
      packDirectory: built.directory.path,
      pinnedPackSha256: '0' * 64,
    );
    expect(find.textContaining('Synthetic pack (pinMismatch)'), findsOne);

    await tester.pumpWidget(const SizedBox());
    await open(tester, packDirectory: built.directory.path);
    expect(find.textContaining('Synthetic pack (pinMissing)'), findsOne);

    final bytes = built.textFile.readAsBytesSync();
    built.textFile.writeAsBytesSync([...bytes]..[bytes.length ~/ 2] ^= 1);
    await tester.pumpWidget(const SizedBox());
    await open(
      tester,
      packDirectory: built.directory.path,
      pinnedPackSha256: sha,
    );
    expect(find.textContaining('Synthetic pack (verifyFailed)'), findsOne);
  });

  testWidgets('a start that is not a surah and an ayah number is refused', (
    tester,
  ) async {
    final bridge = await open(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Start surah'), 'x');
    await tapButton(tester, 'Publish');
    expect(find.text('the start needs a surah and an ayah number'), findsOne);
    await tester.enterText(find.widgetWithText(TextField, 'Start surah'), '9');
    await tapButton(tester, 'Publish');
    expect(find.text('no ayah at or after 9:1'), findsOne);
    expect(bridge.calls, isEmpty);
  });

  testWidgets('an unreadable results file is moved aside and S4 goes on', (
    tester,
  ) async {
    File('${storage.path}/s4-results.json').writeAsStringSync('{"spike":');
    await open(tester);
    expect(find.textContaining('Synthetic pack (noPack)'), findsOneWidget);
    await tapButton(tester, 'Pin the widget');
    expect(find.textContaining('Pin requested at'), findsOneWidget);
    expect(results()['pins'], hasLength(1));
    final names = storage.listSync().map((f) => f.uri.pathSegments.last);
    expect(
      names.where((n) => n.startsWith('s4-results.json.unreadable-')),
      hasLength(1),
    );
    expect(names, isNot(contains('s4-results.json.partial')));
  });

  testWidgets('opened by a tap it shows the address and records it with '
      'the ayah each face shows today (WG-02)', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester);
    await tapButton(tester, 'Publish');
    final first = pack.ayat.first.address;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(ReadingTheme.paper),
        home: S4Screen(
          environment: fakeS4Environment(
            bridge: FakeWidgetBridge(),
            storage: storage,
            pack: pack,
          ),
          openedBy: (address: first, launch: WidgetLaunch.cold),
        ),
      ),
    );
    await settleIo(tester);
    expect(find.text('Opened by a widget tap (cold): $first'), findsOneWidget);
    final link =
        (results()['links']! as List<Object?>).single! as Map<String, Object?>;
    expect(link['address'], '$first');
    expect(link['launch'], 'cold');
    expect(link['shownToday'], {'medium': '$first', 'small': '$first'});
    expect(find.byType(AyahWidgetFace), findsNWidgets(4));
    expect(find.textContaining('medium, today $first'), findsOneWidget);
  });

  testWidgets('no text outside the faces holds an Arabic code point', (
    tester,
  ) async {
    // Tall enough that the list builds every row at once.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open(tester);
    await tapButton(tester, 'Publish');
    await tapButton(tester, 'Run the probe');
    expect(find.byType(AyahWidgetFace), findsNWidgets(4));
    final texts = chromeTexts(tester).toList();
    expect(texts, isNotEmpty);
    for (final text in texts) {
      expect(text.runes.where(_isArabic), isEmpty, reason: text);
    }
  });

  testWidgets('every button and field is at least 48 by 48', (tester) async {
    await open(tester);
    await tapButton(tester, 'Publish');
    final targets = [
      find.byType(FilledButton),
      find.byType(OutlinedButton),
      find.byType(TextField),
    ];
    for (final finder in targets) {
      for (final element in finder.evaluate()) {
        final size = (element.renderObject! as RenderBox).size;
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    }
  });

  testWidgets('at 200% text on a narrow phone the chrome lays out without '
      'overflow', (tester) async {
    // Narrow, and tall enough that the list builds every row at once.
    tester.view.physicalSize = const Size(360, 4000) * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester);
    await tapButton(tester, 'Publish');
    await tapButton(tester, 'Pin the widget');
    await tapButton(tester, 'Run the probe');
    expect(tester.takeException(), isNull);
    final inFaces = find
        .descendant(
          of: find.byType(AyahWidgetFace),
          matching: find.byType(RichText),
        )
        .evaluate()
        .toSet();
    for (final element in find.byType(RichText).evaluate()) {
      if (inFaces.contains(element)) continue;
      final paragraph = element.renderObject! as RenderParagraph;
      expect(paragraph.size.width, lessThanOrEqualTo(360));
      expect(paragraph.didExceedMaxLines, isFalse);
    }
    expect(_renderRatios.toSet(), {3.0});
    expectFaces(tester);
  });
}
