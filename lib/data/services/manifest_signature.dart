import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

enum SignatureCheck { valid, invalid, notChecked }

/// Checks the detached signature `manifest.json.sig` over the exact bytes of
/// `manifest.json` (docs/CONTENT_PACKS.md). [signature] is null when the pack
/// has no signature file.
abstract interface class ManifestSignatureVerifier {
  Future<SignatureCheck> verify({
    required Uint8List manifest,
    required Uint8List? signature,
  });
}

/// A verifier that checks nothing, for tests of what follows the check. It
/// answers [SignatureCheck.notChecked] for every manifest and
/// never [SignatureCheck.valid].
final class SignatureNotConfigured implements ManifestSignatureVerifier {
  const SignatureNotConfigured();

  @override
  Future<SignatureCheck> verify({
    required Uint8List manifest,
    required Uint8List? signature,
  }) async => SignatureCheck.notChecked;
}

/// Checks the signature with Ed25519 (D-080, D-108): `manifest.json.sig` is
/// the raw 64-byte signature of the exact bytes of `manifest.json`, and a
/// signature made with any of the accepted keys is [SignatureCheck.valid].
/// With no key, or no signature file, the answer is
/// [SignatureCheck.notChecked]; what a caller then accepts is its policy.
final class Ed25519ManifestVerifier implements ManifestSignatureVerifier {
  /// Throws an [ArgumentError] when a key is not 32 bytes long.
  Ed25519ManifestVerifier(List<List<int>> publicKeys)
    : _keys = [
        for (final key in publicKeys)
          key.length == _keyLength
              ? SimplePublicKey(key, type: KeyPairType.ed25519)
              : throw ArgumentError.value(
                  key.length,
                  'publicKeys',
                  'holds a key that is not $_keyLength bytes long',
                ),
      ];

  static const _keyLength = 32;
  static const _signatureLength = 64;

  final List<SimplePublicKey> _keys;
  final _algorithm = Ed25519();

  @override
  Future<SignatureCheck> verify({
    required Uint8List manifest,
    required Uint8List? signature,
  }) async {
    if (_keys.isEmpty || signature == null) return SignatureCheck.notChecked;
    if (signature.length != _signatureLength) return SignatureCheck.invalid;
    for (final key in _keys) {
      if (await _algorithm.verify(
        manifest,
        signature: Signature(signature, publicKey: key),
      )) {
        return SignatureCheck.valid;
      }
    }
    return SignatureCheck.invalid;
  }
}
