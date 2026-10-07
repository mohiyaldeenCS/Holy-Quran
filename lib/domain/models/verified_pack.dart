import 'pack_manifest.dart';

/// A pack whose files matched its manifest. [signatureChecked] is false while
/// no signing key exists (D-024).
final class VerifiedPack {
  const VerifiedPack({
    required this.directory,
    required this.manifest,
    required this.signatureChecked,
  });

  final String directory;
  final PackManifest manifest;
  final bool signatureChecked;
}
