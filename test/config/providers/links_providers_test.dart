import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/links_providers.dart';
import 'package:holyquran/data/services/link_service.dart';

void main() {
  test('provides the service that opens links', () async {
    late LinkService service;
    final providers = await buildDependencies(
      areas: [linksProviders, (d) async => service = d.read<LinkService>()],
    );

    expect(providers, hasLength(1));
    expect(service, isA<SystemLinkService>());
  });
}
