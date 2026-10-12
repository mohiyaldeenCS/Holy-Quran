import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/catalogue_config.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/catalogue_providers.dart';
import 'package:holyquran/domain/models/catalogue.dart';
import 'package:holyquran/utils/result.dart';

void main() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final messages = <String>[];

  setUp(() {
    messages.clear();
    messenger.allMessagesHandler = (channel, handler, message) {
      messages.add(channel);
      return null;
    };
  });

  tearDown(() => messenger.allMessagesHandler = null);

  test('the area provides the catalogue only once it is configured', () async {
    final providers = await buildDependencies(areas: [catalogueProviders]);
    expect(providers, catalogueUrl == null ? isEmpty : hasLength(1));
  });

  test('the catalogue builds without touching a plugin', () async {
    final repository = catalogueRepository(
      Uri.parse('https://example.invalid/catalogue.json'),
    );
    addTearDown(repository.dispose);
    await pumpEventQueue();
    expect(messages, isEmpty);
    expect(repository.catalogue, isNull);
  });

  test('the catalogue is fetched over https only', () async {
    final repository = catalogueRepository(
      Uri.parse('http://example.invalid/catalogue.json'),
    );
    addTearDown(repository.dispose);
    expect(
      await repository.refresh(),
      isA<Failure<Catalogue>>().having(
        (f) => f.error,
        'error',
        isA<CatalogueRejected>(),
      ),
    );
  });
}
