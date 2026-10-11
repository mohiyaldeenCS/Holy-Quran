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

void main() {
  test('the widget provider holds every key, field and link part', () {
    final source = _read(_provider);
    final names = [
      ...[for (final size in WidgetFaceSize.values) size.name],
      slotsKey(
        WidgetFaceSize.medium,
      ).replaceFirst(WidgetFaceSize.medium.name, ''),
      labelsKey,
      SlotField.address,
      SlotField.slotStartMs,
      SlotField.lightPath,
      SlotField.darkPath,
      SlotField.packTextSha256,
      SlotField.lightBytes,
      SlotField.darkBytes,
      SlotField.renderMs,
      WidgetLink.scheme,
      WidgetLink.host,
      WidgetLink.address,
    ];
    for (final name in names) {
      expect(source, contains(_literal(name)), reason: name);
    }
    expect(
      source,
      contains('file.length() != bytes'),
      reason: 'an image whose length is not the slot\'s is refused',
    );
    for (final size in WidgetFaceSize.values) {
      expect(
        slotsKey(size),
        slotsKey(WidgetFaceSize.medium).replaceFirst('medium', size.name),
      );
    }
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
