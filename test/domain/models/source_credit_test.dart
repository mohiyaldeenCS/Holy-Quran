import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/source_credit.dart';

import '../../ui/features/sources/sources_fixtures.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('source_credit'));
  tearDown(() => root.deleteSync(recursive: true));

  test('lists each source of a pack with its name, link and texts', () async {
    final pack = await installedWithSource(root);

    final credits = sourcesOf([pack.manifest]);

    expect(credits.first.name, 'Synthetic source name');
    expect(credits.first.url, 'https://example.invalid/synthetic/source');
    expect(credits.first.publisher, 'Synthetic publisher');
    expect(credits.first.version, '1');
    expect(credits.first.licenceText, 'Synthetic licence text');
    expect(credits.first.notice, 'Synthetic credit notice');
    expect(credits, hasLength(pack.manifest.sources.length));
  });

  test('lists a source that several packs share once', () async {
    final first = await installedWithSource(root, id: 'synthetic-a');
    final second = await installedWithSource(root, id: 'synthetic-b');

    expect(
      sourcesOf([first.manifest, second.manifest]),
      sourcesOf([first.manifest]),
    );
  });

  test('keeps the distinct sources of one pack, in order', () async {
    final pack = await installedWithSource(root);

    expect(pack.manifest.sources.length, greaterThan(1));
    expect(
      [
        for (final credit in sourcesOf([pack.manifest])) credit.name,
      ],
      [for (final source in pack.manifest.sources) source.name],
    );
  });

  test('leaves empty texts null', () async {
    final pack = await installedWithSource(
      root,
      licenceText: '  ',
      notice: null,
      publisher: ' ',
      version: '',
    );

    expect(sourcesOf([pack.manifest]).first.licenceText, isNull);
    expect(sourcesOf([pack.manifest]).first.notice, isNull);
    expect(sourcesOf([pack.manifest]).first.publisher, isNull);
    expect(sourcesOf([pack.manifest]).first.version, isNull);
  });

  test('has no sources when no pack is installed', () {
    expect(sourcesOf(const []), isEmpty);
  });
}
