import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/base_pack.dart';

void main() {
  test('a bundled base pack has its manifest and signature in the assets', () {
    if (bundledBasePack case (:final id, :final version)) {
      final directory = 'assets/packs/$id/$version';
      expect(File('$directory/manifest.json').existsSync(), isTrue);
      expect(File('$directory/manifest.json.sig').existsSync(), isTrue);
    } else {
      expect(Directory('assets/packs').existsSync(), isFalse);
    }
  });
}
