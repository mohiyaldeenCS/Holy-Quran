import 'dart:typed_data';

import '../../domain/models/pack_failure.dart';
import '../../domain/models/pack_manifest.dart';
import '../../domain/models/verified_pack.dart';
import '../../utils/result.dart';
import '../models/pack_manifest_json.dart';
import '../services/manifest_signature.dart';
import '../services/pack_file_service.dart';
import 'pack_repository.dart';

/// Verifies a pack in a directory of the device. A failure names the
/// directory. A file the manifest lists but the directory lacks is a
/// [FileHashMismatch], like a file with other bytes.
final class LocalPackRepository implements PackRepository {
  const LocalPackRepository({required this._files, required this._signatures});

  static const _manifest = 'manifest.json';
  static const _signature = 'manifest.json.sig';

  final PackFileService _files;
  final ManifestSignatureVerifier _signatures;

  @override
  Future<Result<VerifiedPack>> verify(String directory) async {
    final Uint8List? manifest;
    final Uint8List? signature;
    try {
      manifest = await _files.readIfExists('$directory/$_manifest');
      signature = await _files.readIfExists('$directory/$_signature');
    } on Exception {
      return Failure(ManifestUnreadable(directory, 'could not be read'));
    }
    if (manifest == null) {
      return Failure(ManifestUnreadable(directory, '$_manifest is missing'));
    }

    final checked = switch (await _signatures.verify(
      manifest: manifest,
      signature: signature,
    )) {
      SignatureCheck.valid => true,
      SignatureCheck.notChecked => false,
      SignatureCheck.invalid => null,
    };
    if (checked == null) return Failure(SignatureRejected(directory));

    final PackManifest parsed;
    switch (parsePackManifest(manifest, pack: directory)) {
      case Ok(:final value):
        parsed = value;
      case Failure(:final error):
        return Failure(error);
    }

    for (final file in parsed.files) {
      final path = '$directory/${file.name}';
      try {
        if (await _files.sizeOf(path) != file.bytes ||
            await _files.sha256Of(path) != file.sha256) {
          return Failure(FileHashMismatch(directory, file.name));
        }
      } on Exception {
        return Failure(FileHashMismatch(directory, file.name));
      }
    }
    return Ok(
      VerifiedPack(
        directory: directory,
        manifest: parsed,
        signatureChecked: checked,
      ),
    );
  }
}
