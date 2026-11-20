import 'package:holyquran/data/services/mail_service.dart';
import 'package:holyquran/utils/result.dart';

/// Sends an error report (O-17, D-127) to [recipient] as a message prepared
/// in the user's mail app, which they see and send themselves.
final class ReportRepository {
  const ReportRepository({required this._mail, required this.recipient});

  final MailService _mail;
  final String recipient;

  Future<Result<void>> send({required String subject, required String body}) =>
      _mail.compose(MailDraft(to: recipient, subject: subject, body: body));
}
