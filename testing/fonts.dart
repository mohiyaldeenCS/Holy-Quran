import 'dart:convert';

import 'package:flutter/services.dart';

Future<void>? _loaded;

/// Loads every family in `FontManifest.json`, so tests draw real glyphs
/// instead of the test font's boxes. Safe to call more than once.
Future<void> loadAppFonts() => _loaded ??= _loadAll();

Future<void> _loadAll() async {
  final manifest = await rootBundle.loadStructuredData<List<Object?>>(
    'FontManifest.json',
    (json) async => jsonDecode(json) as List<Object?>,
  );
  for (final entry in manifest.cast<Map<String, Object?>>()) {
    final loader = FontLoader(entry['family']! as String);
    for (final font
        in (entry['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(font['asset']! as String));
    }
    await loader.load();
  }
}
