import 'package:url_launcher/url_launcher.dart';

import '../../utils/result.dart';
import 'mail_service.dart';

/// The link was not an `http` or `https` address with a host, or the system
/// had nothing to open it with. [address] is the address as given.
final class LinkNotOpened implements Exception {
  const LinkNotOpened(this.address);

  final String address;

  @override
  String toString() => 'LinkNotOpened($address)';
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
    if ((url.scheme != 'https' && url.scheme != 'http') || url.host.isEmpty) {
      return Failure(LinkNotOpened('$url'));
    }
    try {
      return await _launch(url)
          ? const Ok(null)
          : Failure(LinkNotOpened('$url'));
    } on Exception catch (error) {
      return Failure(error);
    }
  }
}

/// Opens the system's mail app through `url_launcher`. It lives here because
/// this file is the app's one door to `url_launcher`, which the privacy guard
/// reviews as one (`test/guards/privacy_test.dart`).
final class SystemMailService implements MailService {
  const SystemMailService([this._launch = _launchExternally]);

  final Future<bool> Function(Uri url) _launch;

  static Future<bool> _launchExternally(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  Future<Result<void>> compose(MailDraft draft) async {
    try {
      return await _launch(draft.uri)
          ? const Ok(null)
          : Failure(MailNotOpened(draft.to));
    } on Exception catch (error) {
      return Failure(error);
    }
  }
}
