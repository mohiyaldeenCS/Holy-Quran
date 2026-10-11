import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import 'widget_bridge.dart';

// HomeWidgetBridge against mocked `home_widget` channels and a temporary
// directory: the calls it makes, the files it writes, and how a refusal and
// a tap come back. The channel names are the plugin's own (0.10.0).

const _channel = MethodChannel('home_widget');
const _events = EventChannel('home_widget/updates');
const _provider = 'com.example.holyquran.AyahWidgetProvider';

/// The `.partial` file savePng writes, recording what it does and what the
/// final image holds at each step; its rename fails when [failRename].
final class _PartialFile implements File {
  _PartialFile(this._real, this._log, {required this.failRename});

  final File _real;
  final List<String> _log;
  final bool failRename;

  String get _final =>
      _real.path.substring(0, _real.path.length - '.partial'.length);

  String _finalBytes() {
    final file = File(_final);
    return file.existsSync() ? '${file.readAsBytesSync()}' : 'absent';
  }

  @override
  String get path => _real.path;

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    _log.add('write $bytes flush $flush, final ${_finalBytes()}');
    await _real.writeAsBytes(bytes, mode: mode, flush: flush);
    _log.add('written, final ${_finalBytes()}');
    return this;
  }

  @override
  Future<File> rename(String newPath) async {
    _log.add('rename to ${newPath == _final ? 'final' : newPath}');
    if (failRename) throw FileSystemException('rename refused', path);
    return _real.rename(newPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late HomeWidgetBridge bridge;
  late List<MethodCall> calls;
  late Map<String, Object?> answers;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('s4_bridge');
    bridge = HomeWidgetBridge(Directory('${root.path}/images'));
    calls = [];
    answers = {};
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return answers.containsKey(call.method) ? answers[call.method] : true;
    });
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(_channel, null);
    messenger.setMockStreamHandler(_events, null);
    await root.delete(recursive: true);
  });

  group('savePng', () {
    test('writes the bytes under the key and returns the path', () async {
      final png = Uint8List.fromList([1, 2, 3]);
      final path = await bridge.savePng('ayah_widget_medium_0_paper', png);
      expect(path, '${root.path}/images/ayah_widget_medium_0_paper.png');
      expect(File(path).readAsBytesSync(), png);
      expect(Directory('${root.path}/images').listSync(), hasLength(1));
      expect(calls, isEmpty);
    });

    test('replaces an earlier image whole', () async {
      await bridge.savePng('k', Uint8List.fromList([1, 2, 3, 4]));
      final path = await bridge.savePng('k', Uint8List.fromList([9]));
      expect(File(path).readAsBytesSync(), [9]);
    });

    group('never leaves the image half-written', () {
      late List<String> log;

      Future<String> save(Uint8List png, {bool failRename = false}) =>
          IOOverrides.runZoned(
            () => bridge.savePng('k', png),
            createFile: (path) {
              final real = Zone.root.run(() => File(path));
              return path.endsWith('.partial')
                  ? _PartialFile(real, log, failRename: failRename)
                  : real;
            },
          );

      setUp(() async {
        log = [];
        await bridge.savePng('k', Uint8List.fromList([1, 2]));
      });

      test('writes beside the image, then renames over it', () async {
        final path = await save(Uint8List.fromList([7, 8, 9]));
        expect(log, [
          'write [7, 8, 9] flush true, final [1, 2]',
          'written, final [1, 2]',
          'rename to final',
        ]);
        expect(File(path).readAsBytesSync(), [7, 8, 9]);
        expect(File('$path.partial').existsSync(), isFalse);
      });

      test('keeps the old image when the rename fails', () async {
        await expectLater(
          save(Uint8List.fromList([7, 8, 9]), failRename: true),
          throwsA(isA<FileSystemException>()),
        );
        expect(log.last, 'rename to final');
        expect(File('${root.path}/images/k.png').readAsBytesSync(), [1, 2]);
      });
    });

    test('refuses a key that is not a safe file name', () async {
      for (final key in ['', '../x', 'a/b', 'a b', 'A', 'x.png']) {
        await expectLater(
          bridge.savePng(key, Uint8List(1)),
          throwsArgumentError,
          reason: key,
        );
      }
    });
  });

  test('saveString saves a String under the key', () async {
    await bridge.saveString('ayah_widget_labels', '{}');
    expect(calls.single.method, 'saveWidgetData');
    expect(calls.single.arguments, {'id': 'ayah_widget_labels', 'data': '{}'});
  });

  test('scheduleUpdates sends epoch milliseconds for the provider', () async {
    final times = [DateTime(2026, 10, 12), DateTime(2026, 10, 13)];
    await bridge.scheduleUpdates(times);
    expect(calls.single.method, 'scheduleWidgetUpdates');
    final arguments = calls.single.arguments as Map<Object?, Object?>;
    expect(arguments['updateTimes'], [
      for (final time in times) time.millisecondsSinceEpoch,
    ]);
    expect(arguments['qualifiedAndroidName'], _provider);
  });

  test('update names the provider', () async {
    await bridge.update();
    expect(calls.single.method, 'updateWidget');
    expect(
      (calls.single.arguments as Map<Object?, Object?>)['qualifiedAndroidName'],
      _provider,
    );
  });

  group('a refusal throws', () {
    for (final (method, run) in <(String, Future<void> Function(WidgetBridge))>[
      ('saveWidgetData', (b) => b.saveString('k', 'v')),
      ('scheduleWidgetUpdates', (b) => b.scheduleUpdates([DateTime(2027)])),
      ('updateWidget', (b) => b.update()),
    ]) {
      for (final answer in [false, null]) {
        test('$method answering $answer', () async {
          answers[method] = answer;
          await expectLater(
            run(bridge),
            throwsA(
              isA<WidgetBridgeException>().having(
                (e) => e.call,
                'call',
                method,
              ),
            ),
          );
        });
      }
    }

    test('a platform error passes through', () async {
      messenger.setMockMethodCallHandler(
        _channel,
        (call) async => throw PlatformException(code: '-3'),
      );
      await expectLater(bridge.update(), throwsA(isA<PlatformException>()));
    });
  });

  group('requestPin', () {
    test('asks the launcher where it can', () async {
      answers['requestPinWidget'] = null;
      expect(await bridge.requestPin(), isTrue);
      expect(
        [for (final call in calls) call.method],
        ['isRequestPinWidgetSupported', 'requestPinWidget'],
      );
      expect(
        (calls.last.arguments as Map<Object?, Object?>)['qualifiedAndroidName'],
        _provider,
      );
    });

    test('does not ask where it cannot', () async {
      answers['isRequestPinWidgetSupported'] = false;
      expect(await bridge.requestPin(), isFalse);
      expect(calls.single.method, 'isRequestPinWidgetSupported');
    });
  });

  group('launchAddress', () {
    test('is the ayah of the launching link', () async {
      answers['initiallyLaunchedFromHomeWidget'] =
          'holyquranspike://ayah?address=hafs%3A2%3A3';
      expect(await bridge.launchAddress(), QuranAddress('hafs', 2, 3));
    });

    test('is null without a launch or with a foreign link', () async {
      for (final answer in [null, '', 'https://x', 'holyquranspike://ayah']) {
        answers['initiallyLaunchedFromHomeWidget'] = answer;
        expect(await bridge.launchAddress(), isNull, reason: '$answer');
      }
    });
  });

  test('taps carry each ayah, or null for a link without one', () async {
    messenger.setMockStreamHandler(
      _events,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          sink
            ..success('holyquranspike://ayah?address=hafs%3A1%3A4')
            ..success(true)
            ..success('holyquranspike://ayah?address=hafs%3A3%3A1')
            ..endOfStream();
        },
      ),
    );
    expect(await bridge.taps.toList(), [
      QuranAddress('hafs', 1, 4),
      null,
      QuranAddress('hafs', 3, 1),
    ]);
  });
}
