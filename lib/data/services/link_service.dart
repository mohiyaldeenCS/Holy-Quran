import 'package:url_launcher/url_launcher.dart';

import '../../utils/result.dart';

/// The link was not an `http` or `https` address, or the system had nothing
/// to open it with.
final class LinkNotOpened implements Exception {
  const LinkNotOpened(this.url);

  final Uri url;

  @override
  String toString() => 'LinkNotOpened($url)';
}

/// Opens a web address outside the app. It sends nothing itself.
abstract interface class LinkService {
  Future<Result<void>> open(Uri url);
}

/// Opens links in the system's browser through `url_launcher`.
final class SystemLinkService implements LinkService {
  const SystemLinkService([this._launch = _launchExternally]);

  final Future<bool> Function(Uri url) _launch;

  static Future<bool> _launchExternally(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  Future<Result<void>> open(Uri url) async {
    if (url.scheme != 'https' && url.scheme != 'http') {
      return Failure(LinkNotOpened(url));
    }
    try {
      return await _launch(url) ? const Ok(null) : Failure(LinkNotOpened(url));
    } on Exception catch (error) {
      return Failure(error);
    }
  }
}
