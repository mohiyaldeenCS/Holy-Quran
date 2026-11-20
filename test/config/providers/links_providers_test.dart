import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/links_providers.dart';
import 'package:holyquran/data/services/link_service.dart';
import 'package:holyquran/data/services/mail_service.dart';

void main() {
  test('provides the services that open links and mail', () async {
    late LinkService links;
    late MailService mail;
    final providers = await buildDependencies(
      areas: [
        linksProviders,
        (d) async {
          links = d.read<LinkService>();
          mail = d.read<MailService>();
        },
      ],
    );

    expect(providers, hasLength(2));
    expect(links, isA<SystemLinkService>());
    expect(mail, isA<SystemMailService>());
  });
}
