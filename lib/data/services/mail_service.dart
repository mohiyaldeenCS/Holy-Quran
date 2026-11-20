import 'package:flutter/foundation.dart';

import '../../utils/result.dart';

/// The system had no mail app to open [address] with.
final class MailNotOpened implements Exception {
  const MailNotOpened(this.address);

  final String address;

  @override
  String toString() => 'MailNotOpened($address)';
}

/// A message prepared for the user's mail app, which they see and send
/// themselves.
@immutable
final class MailDraft {
  const MailDraft({
    required this.to,
    required this.subject,
    required this.body,
  });

  final String to;
  final String subject;
  final String body;

  /// The draft as a `mailto:` link (RFC 6068). Spaces are `%20`, not `+`,
  /// which mail apps would show as written.
  Uri get uri => Uri(
    scheme: 'mailto',
    path: to,
    query:
        'subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}',
  );

  @override
  bool operator ==(Object other) =>
      other is MailDraft &&
      other.to == to &&
      other.subject == subject &&
      other.body == body;

  @override
  int get hashCode => Object.hash(to, subject, body);
}

/// Opens the user's mail app with a prepared message. It sends nothing
/// itself.
abstract interface class MailService {
  Future<Result<void>> compose(MailDraft draft);
}

/// Opens the system's mail app with the launcher it is given, which in the
/// app is the link service's `launchExternally`: only that file may call
/// `url_launcher` (`test/guards/privacy_test.dart`).
final class SystemMailService implements MailService {
  const SystemMailService(this._launch);

  final Future<bool> Function(Uri url) _launch;

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
