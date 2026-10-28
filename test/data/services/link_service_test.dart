import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/link_service.dart';
import 'package:holyquran/utils/result.dart';

void main() {
  final https = Uri.parse('https://example.invalid/synthetic');

  test('opens a web address', () async {
    final launched = <Uri>[];
    final service = SystemLinkService((url) async {
      launched.add(url);
      return true;
    });

    expect(await service.open(https), isA<Ok<void>>());
    expect(launched, [https]);
  });

  for (final scheme in ['file', 'javascript', 'tel']) {
    test('refuses a $scheme address without launching it', () async {
      var launched = false;
      final service = SystemLinkService((url) async => launched = true);

      final result = await service.open(Uri.parse('$scheme:synthetic'));

      expect(
        result,
        isA<Failure<void>>().having(
          (failure) => failure.error,
          'error',
          isA<LinkNotOpened>(),
        ),
      );
      expect(launched, isFalse);
    });
  }

  test('fails when the system has nothing to open it with', () async {
    final service = SystemLinkService((url) async => false);

    expect(await service.open(https), isA<Failure<void>>());
  });

  test('fails when the plugin throws', () async {
    final service = SystemLinkService((url) => throw Exception('synthetic'));

    expect(await service.open(https), isA<Failure<void>>());
  });
}
