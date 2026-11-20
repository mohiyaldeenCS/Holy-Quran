import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/report_repository.dart';
import 'package:holyquran/data/services/mail_service.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_mail_service.dart';

void main() {
  test('prepares the report for the recipient in the mail app', () async {
    final mail = FakeMailService();
    final reports = ReportRepository(
      mail: mail,
      recipient: 'reports@example.org',
    );

    final result = await reports.send(subject: 'نص تجريبي', body: 'hafs:2:3');

    expect(result, isA<Ok<void>>());
    expect(mail.composed, [
      const MailDraft(
        to: 'reports@example.org',
        subject: 'نص تجريبي',
        body: 'hafs:2:3',
      ),
    ]);
  });

  test('passes on that no mail app opened', () async {
    final mail = FakeMailService()..fails = true;
    final reports = ReportRepository(
      mail: mail,
      recipient: 'reports@example.org',
    );

    final result = await reports.send(subject: 'نص تجريبي', body: 'hafs:2:3');

    expect((result as Failure<void>).error, isA<MailNotOpened>());
  });
}
