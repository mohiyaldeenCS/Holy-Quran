import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/signing_keys.dart';
import 'package:holyquran/data/services/manifest_signature.dart';

void main() {
  test('holds at most the key in use and a spare, each of 32 bytes', () {
    expect(manifestPublicKeys.length, lessThanOrEqualTo(2));
    expect(() => Ed25519ManifestVerifier(manifestPublicKeys), returnsNormally);
    expect(
      {for (final key in manifestPublicKeys) key.join(',')}.length,
      manifestPublicKeys.length,
    );
  });
}
