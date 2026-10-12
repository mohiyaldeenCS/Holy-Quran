import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
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

  ed25519Tests();
}

void ed25519Tests() {
  group('Ed25519ManifestVerifier', () {
    final algorithm = Ed25519();
    final manifest = Uint8List.fromList(utf8.encode('{"synthetic": 1}'));

    Future<(List<int>, Uint8List)> keyAndSignature([Uint8List? bytes]) async {
      final pair = await algorithm.newKeyPair();
      final signature = await algorithm.sign(bytes ?? manifest, keyPair: pair);
      return (
        (await pair.extractPublicKey()).bytes,
        Uint8List.fromList(signature.bytes),
      );
    }

    test('a signature by the key in use is valid', () async {
      final (key, signature) = await keyAndSignature();
      expect(
        await Ed25519ManifestVerifier([
          key,
        ]).verify(manifest: manifest, signature: signature),
        SignatureCheck.valid,
      );
    });

    test('a signature by the spare key is valid', () async {
      final (inUse, _) = await keyAndSignature();
      final (spare, signature) = await keyAndSignature();
      expect(
        await Ed25519ManifestVerifier([
          inUse,
          spare,
        ]).verify(manifest: manifest, signature: signature),
        SignatureCheck.valid,
      );
    });

    test('a tampered manifest or signature is invalid', () async {
      final (key, signature) = await keyAndSignature();
      final verifier = Ed25519ManifestVerifier([key]);
      final tampered = Uint8List.fromList(manifest)..[2] ^= 1;
      expect(
        await verifier.verify(manifest: tampered, signature: signature),
        SignatureCheck.invalid,
      );
      final flipped = Uint8List.fromList(signature)..[0] ^= 1;
      expect(
        await verifier.verify(manifest: manifest, signature: flipped),
        SignatureCheck.invalid,
      );
    });

    test('a signature by another key is invalid', () async {
      final (key, _) = await keyAndSignature();
      final (_, other) = await keyAndSignature();
      expect(
        await Ed25519ManifestVerifier([
          key,
        ]).verify(manifest: manifest, signature: other),
        SignatureCheck.invalid,
      );
    });

    test('a signature that is not 64 bytes long is invalid', () async {
      final (key, signature) = await keyAndSignature();
      final verifier = Ed25519ManifestVerifier([key]);
      for (final length in [0, 63, 65]) {
        final wrong = Uint8List(length)
          ..setRange(0, length < 64 ? length : 64, signature);
        expect(
          await verifier.verify(manifest: manifest, signature: wrong),
          SignatureCheck.invalid,
          reason: '$length bytes',
        );
      }
    });

    test('with no key or no signature file, it is not checked', () async {
      final (key, signature) = await keyAndSignature();
      expect(
        await Ed25519ManifestVerifier(
          const [],
        ).verify(manifest: manifest, signature: signature),
        SignatureCheck.notChecked,
      );
      expect(
        await Ed25519ManifestVerifier([
          key,
        ]).verify(manifest: manifest, signature: null),
        SignatureCheck.notChecked,
      );
    });

    test('a key that is not 32 bytes long is refused', () {
      expect(
        () => Ed25519ManifestVerifier([List.filled(31, 0)]),
        throwsArgumentError,
      );
    });
  });
}
