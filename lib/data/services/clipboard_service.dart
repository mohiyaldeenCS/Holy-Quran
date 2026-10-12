import 'package:flutter/services.dart';

import '../../utils/result.dart';

/// Puts text on the system clipboard.
abstract interface class ClipboardService {
  Future<Result<void>> copyText(String text);
}

/// Copies through the platform clipboard. The text may hold pack text, so it
/// is handed over exactly as it arrives.
final class SystemClipboardService implements ClipboardService {
  const SystemClipboardService();

  @override
  Future<Result<void>> copyText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return const Ok(null);
    } on PlatformException catch (error) {
      return Failure(error);
    }
  }
}
