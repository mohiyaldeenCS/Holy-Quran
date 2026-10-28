import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../../utils/result.dart';

/// Hands content to the system share sheet. It sends nothing itself (D-122).
abstract interface class ShareService {
  /// Shares [png], the bytes of one PNG image, as a file named [fileName].
  Future<Result<void>> shareImage(Uint8List png, {required String fileName});
}

/// Shares through `share_plus`. A sheet the user dismisses is not a failure.
final class SystemShareService implements ShareService {
  const SystemShareService();

  @override
  Future<Result<void>> shareImage(
    Uint8List png, {
    required String fileName,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
          fileNameOverrides: [fileName],
        ),
      );
      return const Ok(null);
    } on Exception catch (error) {
      return Failure(error);
    }
  }
}
