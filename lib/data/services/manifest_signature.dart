import 'dart:typed_data';

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

/// The verifier while no public key exists: none does until D-024 is
/// settled. It answers [SignatureCheck.notChecked] for every manifest and
/// never [SignatureCheck.valid].
final class SignatureNotConfigured implements ManifestSignatureVerifier {
  const SignatureNotConfigured();

  @override
  Future<SignatureCheck> verify({
    required Uint8List manifest,
    required Uint8List? signature,
  }) async => SignatureCheck.notChecked;
}
