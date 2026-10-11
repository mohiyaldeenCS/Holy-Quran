import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'native_shaping_probe.dart';

// The shaping probe's Dart side against a mocked channel: what it sends,
// how it reads the answer, and that a malformed answer is refused. The
// samples are synthetic. And ShapingProbe.kt, which cannot run on Linux,
// checked against the names the Dart uses.

const _channel = MethodChannel('holyquran.spike/shaping_probe');
const _kotlin = 'android/app/src/main/kotlin/com/example/holyquran';
const _probe = '$_kotlin/ShapingProbe.kt';
const _activity = '$_kotlin/MainActivity.kt';
const _fontAsset = 'assets/fonts/AmiriQuran-Regular.ttf';

String _read(String path) => File(path).readAsStringSync();

/// [text] as a Kotlin string literal.
String _literal(String text) => '"$text"';
final _digest = 'c0' * 32;

Map<String, Object?> _answer() => {
  'width': 120.5,
  'height': 88,
  'lineCount': 2,
  'lineStarts': [0, 11],
  'lineWidths': [120.5, 60.25],
  'fontSha256': _digest,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Object? answer;

  setUp(() {
    calls = [];
    answer = _answer();
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return answer;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test('sends the sample text, size and width to measure', () async {
    await const MethodChannelShapingProbe().measure(
      ShapingSample.marks,
      fontSize: 24,
      maxWidth: 300,
    );
    expect(calls.single.method, 'measure');
    expect(calls.single.arguments, {
      'text': shapingSampleText(ShapingSample.marks),
      'fontSize': 24.0,
      'maxWidth': 300.0,
    });
  });

  test('reads the answer in logical pixels', () async {
    final result = await const MethodChannelShapingProbe().measure(
      ShapingSample.plain,
      fontSize: 24,
      maxWidth: 300,
    );
    expect(result.fontSha256, _digest);
    final m = result.measure;
    expect((m.width, m.height, m.lineCount), (120.5, 88.0, 2));
    expect(m.lineStarts, [0, 11]);
    expect(m.lineWidths, [120.5, 60.25]);
  });

  test('refuses a malformed answer', () async {
    final malformed = <Object?>[
      null,
      'nope',
      {..._answer()}..remove('height'),
      {..._answer(), 'lineCount': 3},
      {
        ..._answer(),
        'lineCount': 0,
        'lineStarts': <int>[],
        'lineWidths': <double>[],
      },
      {
        ..._answer(),
        'lineStarts': [1, 11],
      },
      {
        ..._answer(),
        'lineStarts': [0, 0],
      },
      {
        ..._answer(),
        'lineStarts': [0, '11'],
      },
      {
        ..._answer(),
        'lineWidths': [1.0],
      },
      {..._answer(), 'width': double.nan},
      {..._answer(), 'height': 0},
      {..._answer(), 'fontSha256': 'C0' * 32},
      {..._answer(), 'fontSha256': 'c0'},
    ];
    for (final bad in malformed) {
      answer = bad;
      await expectLater(
        const MethodChannelShapingProbe().measure(
          ShapingSample.long,
          fontSize: 24,
          maxWidth: 300,
        ),
        throwsFormatException,
        reason: '$bad',
      );
    }
  });

  group('samples', () {
    test('are distinct and Arabic letters, marks and spaces only', () {
      final texts = [
        for (final s in ShapingSample.values) shapingSampleText(s),
      ];
      expect(texts.toSet(), hasLength(texts.length));
      for (final text in texts) {
        for (final rune in text.runes) {
          expect(
            rune == 0x20 ||
                (rune >= 0x621 && rune <= 0x652) ||
                (rune >= 0x6D6 && rune <= 0x6DC),
            isTrue,
            reason: rune.toRadixString(16),
          );
        }
      }
    });

    test('the marks sample holds each pause mark as a token of its own', () {
      final tokens = shapingSampleText(ShapingSample.marks).split(' ');
      for (var mark = 0x6D6; mark <= 0x6DC; mark++) {
        expect(tokens, contains(String.fromCharCode(mark)));
      }
    });

    test('the vowelled sample has harakat', () {
      expect(
        shapingSampleText(
          ShapingSample.vowelled,
        ).runes.where((rune) => rune >= 0x64B && rune <= 0x652),
        isNotEmpty,
      );
    });
  });

  group('native source', () {
    test('ShapingProbe.kt holds the channel, method and every field', () {
      final source = _read(_probe);
      for (final name in [
        ShapingChannel.name,
        ShapingChannel.measure,
        ShapingChannel.text,
        ShapingChannel.fontSize,
        ShapingChannel.maxWidth,
        ShapingChannel.width,
        ShapingChannel.height,
        ShapingChannel.lineCount,
        ShapingChannel.lineStarts,
        ShapingChannel.lineWidths,
        ShapingChannel.fontSha256,
      ]) {
        expect(source, contains(_literal(name)), reason: name);
      }
      expect(_read('pubspec.yaml'), contains('asset: $_fontAsset\n'));
      expect(source, contains(_literal(_fontAsset)));
      expect(
        _read(_activity),
        contains(
          'ShapingProbe(applicationContext, '
          'flutterEngine.dartExecutor.binaryMessenger)',
        ),
      );
    });

    test('is ASCII and logs nothing', () {
      final ascii = RegExp(r'^[\x09\x0a\x0d\x20-\x7e]*$');
      for (final path in [_probe, _activity]) {
        expect(ascii.hasMatch(_read(path)), isTrue, reason: path);
        expect(_read(path), isNot(contains('Log.')), reason: path);
      }
    });
  });
}
