import '../../domain/models/verified_pack.dart';
import '../../utils/result.dart';

abstract interface class PackRepository {
  /// Checks the pack in [directory] (docs/CONTENT_PACKS.md, "Verification
  /// order in the app", steps 1 to 3): its signature, its manifest, and the
  /// size and SHA-256 of every file it lists.
  Future<Result<VerifiedPack>> verify(String directory);
}
