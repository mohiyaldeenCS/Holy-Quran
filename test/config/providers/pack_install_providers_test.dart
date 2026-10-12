import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/pack_install_providers.dart';
import 'package:holyquran/domain/models/install_job.dart';
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

  test('the area provides nothing until the installer is hooked up', () async {
    expect(await buildDependencies(areas: [packInstallProviders]), isEmpty);
  });

  test('the installer builds without touching a plugin', () async {
    final repository = packInstallRepository();
    addTearDown(repository.dispose);
    await pumpEventQueue();
    expect(messages, isEmpty);
    expect(repository.installed, isEmpty);
    expect(repository.jobs, isEmpty);
  });

  test('the installer accepts https URLs only', () async {
    final repository = packInstallRepository();
    addTearDown(repository.dispose);
    final url = Uri.parse('http://example.invalid/synthetic/manifest.json');
    final result = await repository.install(
      InstallRequest(
        packId: 'synthetic-text',
        version: 1,
        manifest: RemoteFile(url: url, sha256: '0' * 64, bytes: 1),
        signature: null,
        files: const {},
        wifiOnly: true,
      ),
    );
    expect(
      result,
      isA<Failure<Object>>().having(
        (f) => f.error,
        'error',
        isA<UrlNotAllowed>().having((e) => e.url, 'url', url),
      ),
    );
    expect(messages, isEmpty);
  });
}
