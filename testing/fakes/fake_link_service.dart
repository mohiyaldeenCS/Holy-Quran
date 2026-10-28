import 'package:holyquran/data/services/link_service.dart';
import 'package:holyquran/utils/result.dart';

/// A [LinkService] that opens nothing, for view and view-model tests. Every
/// link asked for is logged in [opened]; it fails while [fails] is set.
final class FakeLinkService implements LinkService {
  bool fails = false;
  final List<Uri> opened = [];

  @override
  Future<Result<void>> open(Uri url) async {
    opened.add(url);
    return fails ? Failure(LinkNotOpened('$url')) : const Ok(null);
  }
}
