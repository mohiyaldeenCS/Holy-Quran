import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/test_copy.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/data/services/share_service.dart';
import 'package:holyquran/domain/models/unapproved_copy_mark.dart';

/// Provides the clipboard and the system share sheet that the copy and share
/// sheets hand an ayah to. Neither touches a plugin until it is used.
Future<void> shareProviders(Dependencies dependencies) async =>
    provideShare(dependencies, unapprovedCopy: testCopy != null);

/// [shareProviders] for a build that is, or is not, the unapproved test
/// copy. The test copy keeps copying, marked by a final line, and offers no
/// share as an image: the drawn card cannot carry the marking (D-162 (14)).
Future<void> provideShare(
  Dependencies dependencies, {
  required bool unapprovedCopy,
}) async {
  dependencies.provide<ClipboardService>(const SystemClipboardService());
  if (unapprovedCopy) {
    dependencies.provide<UnapprovedCopyMark>(const UnapprovedCopyMark());
  } else {
    dependencies.provide<ShareService>(const SystemShareService());
  }
}
