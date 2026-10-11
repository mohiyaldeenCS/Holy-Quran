import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'widget_bridge.dart';
import 'widget_slots.dart';

// The Android side of S4 cannot run on Linux, so its sources are checked
// against the Dart it mirrors (D-094): every shared name, no text of its own,
// ASCII only, and grounds equal to the tokens. The shaping probe's sources
// are checked in native_shaping_probe_test.dart.

const _main = 'android/app/src/main';
const _kotlin = '$_main/kotlin/com/example/holyquran';
const _provider = '$_kotlin/AyahWidgetProvider.kt';
const _layout = '$_main/res/layout/ayah_widget.xml';
const _info = '$_main/res/xml/ayah_widget_info.xml';
const _paper = '$_main/res/values/spike_widget.xml';
const _night = '$_main/res/values-night/spike_widget.xml';
const _manifest = '$_main/AndroidManifest.xml';

const _nativeFiles = [_provider, _layout, _info, _paper, _night, _manifest];

String _read(String path) => File(path).readAsStringSync();

/// [text] as a Kotlin string literal.
String _literal(String text) => '"$text"';

const _slotFields = [
  SlotField.address,
  SlotField.slotStartMs,
  SlotField.lightPath,
  SlotField.darkPath,
  SlotField.packTextSha256,
  SlotField.lightBytes,
  SlotField.darkBytes,
  SlotField.lightSha256,
  SlotField.darkSha256,
  SlotField.renderMs,
];

/// What lies between the brace that opens after [head] in [source] and the
/// brace that closes it.
String _block(String source, String head) {
  final start = source.indexOf(head);
  if (start < 0) throw TestFailure('$head is not in the source');
  final open = source.indexOf('{', start + head.length);
  var depth = 0;
  for (var at = open; at < source.length; at++) {
    if (source[at] == '{') depth++;
    if (source[at] == '}' && --depth == 0) {
      return source.substring(open + 1, at);
    }
  }
  throw StateError('$head has no closing brace');
}

void main() {
  test('the widget provider holds every key, field and link part', () {
    final source = _read(_provider);
    final names = [
      ...[for (final size in WidgetFaceSize.values) size.name],
      slotsKey(
        WidgetFaceSize.medium,
      ).replaceFirst(WidgetFaceSize.medium.name, ''),
      labelsKey,
      ..._slotFields,
      WidgetLink.scheme,
      WidgetLink.host,
      WidgetLink.address,
    ];
    for (final name in names) {
      expect(source, contains(_literal(name)), reason: name);
    }
    for (final size in WidgetFaceSize.values) {
      expect(
        slotsKey(size),
        slotsKey(WidgetFaceSize.medium).replaceFirst('medium', size.name),
      );
    }
  });

  test('a slot missing any field is unreadable', () {
    final source = _read(_provider);
    final constants = {
      for (final match in RegExp(
        r'const val (\w+) = "([^"]*)"',
      ).allMatches(source))
        match[1]!: match[2]!,
    };
    final list = RegExp(
      r'val FIELDS = listOf\(([^)]*)\)',
    ).firstMatch(source)![1]!;
    final fields = [
      for (final entry in list.split(','))
        if (entry.trim() case final name when name.isNotEmpty)
          name.startsWith('"')
              ? name.substring(1, name.length - 1)
              : constants[name]!,
    ];
    expect(fields, unorderedEquals(_slotFields));
    expect(source, contains('if (FIELDS.any { !entry.has(it) })'));
  });

  test('an image is decoded from the bytes checked against its slot', () {
    final body = _block(_read(_provider), 'private fun image(');
    final read = body.indexOf('File(path).readBytes()');
    final length = body.indexOf('if (data.size.toLong() != bytes) return null');
    final digest = body.indexOf('if (sha256Hex(data) != sha256) return null');
    final decode = body.indexOf(
      'return BitmapFactory.decodeByteArray(data, 0, data.size)',
    );
    expect([read, length, digest, decode], everyElement(isNonNegative));
    expect(read < length && length < digest && digest < decode, isTrue);
    expect(body, contains('catch (unreadable: IOException)'));
    expect(_read(_provider), isNot(contains('decodeFile')));
    expect(
      _read(_provider),
      contains(
        'MessageDigest.getInstance("SHA-256").digest(data)'
        '.joinToString("") { "%02x".format(it) }',
      ),
      reason: 'lowercase hex, as the publisher stores it',
    );
  });

  test('the provider class is the one the bridge names', () {
    final dot = ayahWidgetProvider.lastIndexOf('.');
    final package = ayahWidgetProvider.substring(0, dot);
    final name = ayahWidgetProvider.substring(dot + 1);
    final source = _read(_provider);
    expect(source, startsWith('package $package\n'));
    expect(source, contains('class $name : HomeWidgetProvider()'));
    expect(_read(_manifest), contains('android:name=".$name"'));
  });

  test('Flutter deep linking is off, so the widget link is not a route', () {
    final activity = RegExp(
      r'<activity\s[^>]*android:name="\.MainActivity"[^>]*>([\s\S]*?)</activity>',
    ).firstMatch(_read(_manifest))![1]!;
    expect(
      RegExp(
        r'<meta-data\s+android:name="flutter_deeplinking_enabled"'
        r'\s+android:value="false"\s*/>',
      ).allMatches(activity),
      hasLength(1),
    );
    expect(
      'flutter_deeplinking_enabled'.allMatches(_read(_manifest)),
      hasLength(1),
    );
  });

  test('the native files are ASCII', () {
    final ascii = RegExp(r'^[\x09\x0a\x0d\x20-\x7e]*$');
    for (final path in _nativeFiles) {
      expect(ascii.hasMatch(_read(path)), isTrue, reason: path);
    }
  });

  test('the widget draws no text of its own and logs nothing', () {
    for (final path in [_provider, _layout, _info]) {
      final source = _read(path);
      for (final banned in [
        'android:text',
        'setTextViewText',
        'TextView',
        'setCharSequence',
        'Log.',
        'android:label',
        'android:description',
        'android:previewImage',
        'android:previewLayout',
      ]) {
        expect(source, isNot(contains(banned)), reason: '$path: $banned');
      }
    }
  });

  test('the widget is redrawn by schedule, not by period', () {
    final info = _read(_info);
    expect(info, contains('android:updatePeriodMillis="0"'));
    expect(info, contains('android:widgetCategory="home_screen"'));
    final manifest = _read(_manifest);
    expect(
      manifest,
      contains(
        'android:name="es.antonborri.home_widget.'
        'HomeWidgetScheduledUpdateReceiver"',
      ),
    );
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
  });

  test('the grounds behind the image are the tokens', () {
    String colour(String path) => RegExp(
      r'<color name="spike_widget_ground">#([0-9A-F]{8})</color>',
    ).firstMatch(_read(path))![1]!;
    String hex(Color c) =>
        c.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0');
    expect(colour(_paper), hex(AppColors.paper.ground));
    expect(colour(_night), hex(AppColors.night.ground));
  });

  test('only widget_bridge.dart imports home_widget', () {
    final importers = [
      for (final dir in ['lib', 'spike', 'test', 'testing'])
        for (final entity in Directory(dir).listSync(recursive: true))
          if (entity is File &&
              entity.path.endsWith('.dart') &&
              _imports(entity.readAsStringSync(), 'home_widget'))
            entity.path,
    ];
    expect(importers, ['spike/s4/widget_bridge.dart']);
  });

  test(
    'of the S4 bridge files only widget_bridge.dart imports path_provider',
    () {
      for (final name in [
        'widget_slots',
        'widget_publisher',
        'native_shaping_probe',
        'shaping_compare',
      ]) {
        expect(
          _read('spike/s4/$name.dart'),
          isNot(predicate<String>((s) => _imports(s, 'path_provider'))),
          reason: name,
        );
      }
    },
  );
}

bool _imports(String source, String package) =>
    RegExp("^import\\s+'package:$package/", multiLine: true).hasMatch(source);
