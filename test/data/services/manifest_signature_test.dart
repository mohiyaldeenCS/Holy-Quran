import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/manifest_signature.dart';

void main() {
  test('SignatureNotConfigured never checks, so never answers valid', () async {
    const verifier = SignatureNotConfigured();
    final manifest = utf8.encode('{"synthetic": true}');
    for (final signature in [null, Uint8List(0), Uint8List(64), manifest]) {
      expect(
        await verifier.verify(manifest: manifest, signature: signature),
        SignatureCheck.notChecked,
      );
    }
    expect(
      await verifier.verify(manifest: Uint8List(0), signature: null),
      SignatureCheck.notChecked,
    );
  });
}
