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
