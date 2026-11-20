import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/link_service.dart';
import 'package:holyquran/data/services/mail_service.dart';
import 'package:holyquran/utils/result.dart';

void main() {
  const draft = MailDraft(
    to: 'reports@example.org',
    subject: 'نص تجريبي',
    body: 'hafs:2:255\r\npack · 3',
  );

  test('opens a mailto link to the recipient, spaces as %20', () async {
    final opened = <Uri>[];
    final service = SystemMailService((url) async {
      opened.add(url);
      return true;
    });

    expect(await service.compose(draft), isA<Ok<void>>());
    final url = opened.single;
    expect(url.scheme, 'mailto');
    expect(url.path, draft.to);
    expect(url.query, isNot(contains('+')));
    expect(Uri.splitQueryString(url.query), {
      'subject': draft.subject,
      'body': draft.body,
    });
  });

  test('fails when no mail app opens it', () async {
    final service = SystemMailService((_) async => false);

    final result = await service.compose(draft);

    expect(result, isA<Failure<void>>());
    expect((result as Failure<void>).error, isA<MailNotOpened>());
  });

  test('fails with the plugin error instead of throwing it', () async {
    final service = SystemMailService(
      (_) async => throw const FormatException('no handler'),
    );

    final result = await service.compose(draft);

    expect((result as Failure<void>).error, isA<FormatException>());
  });
}
