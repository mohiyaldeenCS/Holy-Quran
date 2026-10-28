import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/data/services/share_service.dart';

/// Provides the clipboard and the system share sheet that the copy and share
/// sheets hand an ayah to. Neither touches a plugin until it is used.
Future<void> shareProviders(Dependencies dependencies) async {
  dependencies
    ..provide<ClipboardService>(const SystemClipboardService())
    ..provide<ShareService>(const SystemShareService());
}
