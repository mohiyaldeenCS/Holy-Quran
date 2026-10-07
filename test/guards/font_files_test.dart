import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _pinnedDir = 'design/design-system/fonts/ttf';
const _fontsDir = 'assets/fonts';
const _licensesDir = 'assets/licenses';

/// File name → SHA-256 from the "Fonts" table of `design/README.md`.
Map<String, String> _pinnedHashes() {
  final lines = File('design/README.md').readAsLinesSync();
  final start = lines.indexWhere((line) => line.trim() == '### Fonts');
  if (start < 0) return const {};
  final row = RegExp(r'`([\w-]+\.ttf)`.*`([0-9a-f]{64})`');
  final hashes = <String, String>{};
  for (final line in lines.skip(start + 1)) {
    if (line.startsWith('#')) break;
    final match = row.firstMatch(line);
    if (match != null) hashes[match[1]!] = match[2]!;
  }
  return hashes;
}

List<String> _names(String dir, String suffix) =>
    Directory(dir)
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith(suffix))
        .toList()
      ..sort();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pinned = _pinnedHashes();

  test('design/README.md pins six font files', () {
    expect(pinned.keys.toList()..sort(), _names(_pinnedDir, '.ttf'));
    expect(pinned, hasLength(6));
  });

  test('assets/fonts holds exactly the pinned files', () {
    expect(_names(_fontsDir, '.ttf'), pinned.keys.toList()..sort());
    expect(_names(_fontsDir, ''), _names(_fontsDir, '.ttf'));
  });

  for (final MapEntry(key: name, value: hash) in pinned.entries) {
    test('$name has the pinned SHA-256', () {
      final bytes = File('$_fontsDir/$name').readAsBytesSync();
      expect(sha256.convert(bytes).toString(), hash);
    });

    test('$name is byte-identical to its design copy', () {
      expect(
        File('$_fontsDir/$name').readAsBytesSync(),
        File('$_pinnedDir/$name').readAsBytesSync(),
      );
    });
  }

  test('assets/licenses holds the three OFL texts of the design folder', () {
    final licences = _names(_licensesDir, '');
    expect(licences, _names(_pinnedDir, '.txt'));
    expect(licences, [
      'OFL-AmiriQuran.txt',
      'OFL-IBMPlexSansArabic.txt',
      'OFL-ReemKufi.txt',
    ]);
    for (final name in licences) {
      expect(
        File('$_licensesDir/$name').readAsBytesSync(),
        File('$_pinnedDir/$name').readAsBytesSync(),
        reason: name,
      );
    }
  });

  test('FontManifest.json registers the three families as pinned', () async {
    final manifest = jsonDecode(
      await rootBundle.loadString('FontManifest.json'),
    );
    expect(manifest, [
      // Added by `uses-material-design: true`, not by the app's font list.
      {
        'family': 'MaterialIcons',
        'fonts': [
          {'asset': 'fonts/MaterialIcons-Regular.otf'},
        ],
      },
      {
        'family': 'Amiri Quran',
        'fonts': [
          {'asset': 'assets/fonts/AmiriQuran-Regular.ttf'},
        ],
      },
      {
        'family': 'Reem Kufi',
        'fonts': [
          {'asset': 'assets/fonts/ReemKufi-Variable.ttf'},
        ],
      },
      {
        'family': 'IBM Plex Sans Arabic',
        'fonts': [
          {
            'asset': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
            'weight': 400,
          },
          {'asset': 'assets/fonts/IBMPlexSansArabic-Medium.ttf', 'weight': 500},
          {
            'asset': 'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
            'weight': 600,
          },
          {'asset': 'assets/fonts/IBMPlexSansArabic-Bold.ttf', 'weight': 700},
        ],
      },
    ]);
  });
}
