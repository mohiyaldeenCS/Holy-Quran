import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/recitation.dart';

final _hash = 'a' * 64;

RemoteFile _remote(String name, {int bytes = 10}) => RemoteFile(
  url: Uri.parse('https://example.invalid/$name'),
  sha256: _hash,
  bytes: bytes,
);

CatalogueEntry _entry({
  String id = 'synthetic-pack',
  PackKind kind = PackKind.tafsir,
  int version = 1,
  String title = 'Synthetic title',
  Uri? signature,
  Map<String, RemoteFile>? files,
  String source = 'Synthetic source',
  String changes = 'Synthetic changes',
  CatalogueRole? role,
}) => CatalogueEntry(
  id: id,
  kind: kind,
  version: version,
  title: title,
  manifest: _remote('manifest.json'),
  signature: signature,
  files: files ?? {'tafsir.sqlite': _remote('tafsir.sqlite')},
  source: source,
  changes: changes,
  role: role,
);

Recitation _recitation({
  String id = 'synthetic-recitation',
  String reciter = 'Synthetic reciter',
  String style = 'Synthetic style',
}) => Recitation(
  id: id,
  reciter: reciter,
  riwaya: 'hafs',
  style: style,
  unit: RecitationUnit.ayah,
  hasWordTiming: false,
  rightsComplete: true,
);

void main() {
  group('CatalogueEntry', () {
    test('keeps its fields and sums its files as its size', () {
      final entry = _entry(
        files: {
          'a.sqlite': _remote('a.sqlite', bytes: 30),
          'b.sqlite': _remote('b.sqlite', bytes: 12),
        },
        role: CatalogueRole.firstUseTafsir,
      );
      expect(entry.id, 'synthetic-pack');
      expect(entry.kind, PackKind.tafsir);
      expect(entry.bytes, 42);
      expect(entry.role, CatalogueRole.firstUseTafsir);
      expect(() => entry.files['c'] = _remote('c'), throwsUnsupportedError);
    });

    test('lists every URL it names', () {
      final signature = Uri.parse('https://example.invalid/manifest.json.sig');
      expect(_entry(signature: signature).urls, [
        Uri.parse('https://example.invalid/manifest.json'),
        signature,
        Uri.parse('https://example.invalid/tafsir.sqlite'),
      ]);
      expect(_entry().urls, hasLength(2));
    });

    test('makes the install request of its version', () {
      final signature = Uri.parse('https://example.invalid/manifest.json.sig');
      final request = _entry(
        version: 3,
        signature: signature,
      ).installRequest(wifiOnly: true);
      expect(request.packId, 'synthetic-pack');
      expect(request.version, 3);
      expect(request.manifest.url, _remote('manifest.json').url);
      expect(request.manifest.sha256, _hash);
      expect(request.signature, signature);
      expect(request.files, {
        'tafsir.sqlite': Uri.parse('https://example.invalid/tafsir.sqlite'),
      });
      expect(request.wifiOnly, isTrue);
    });

    test('refuses a malformed entry', () {
      for (final make in <void Function()>[
        () => _entry(id: 'Upper'),
        () => _entry(id: '-leading'),
        () => _entry(version: 0),
        () => _entry(files: {}),
        () => _entry(files: {'../x': _remote('x')}),
        () => _entry(files: {'a/b': _remote('x')}),
        () => _entry(files: {r'a\b': _remote('x')}),
        () => _entry(files: {'': _remote('x')}),
        () => _entry(files: {'x': _remote('x', bytes: 0)}),
        () => _entry(title: ''),
        () => _entry(source: ''),
        () => _entry(changes: ''),
        () => _entry(
          kind: PackKind.recitation,
          role: CatalogueRole.firstUseTafsir,
        ),
      ]) {
        expect(make, throwsArgumentError);
      }
    });
  });

  group('CatalogueRecitation', () {
    test('keeps its recitation, qualities and pack', () {
      final recitation = CatalogueRecitation(
        recitation: _recitation(),
        qualities: [64, 128],
        packId: 'synthetic-pack',
      );
      expect(recitation.id, 'synthetic-recitation');
      expect(recitation.qualities, [64, 128]);
      expect(recitation.packId, 'synthetic-pack');
      expect(() => recitation.qualities.add(1), throwsUnsupportedError);
    });

    test('refuses a malformed recitation', () {
      for (final (recitation, qualities) in [
        (_recitation(id: 'Upper'), [64]),
        (_recitation(), <int>[]),
        (_recitation(), [0]),
        (_recitation(), [128, 64]),
        (_recitation(), [64, 64]),
        (_recitation(reciter: ''), [64]),
        (_recitation(style: ''), [64]),
      ]) {
        expect(
          () => CatalogueRecitation(
            recitation: recitation,
            qualities: qualities,
            packId: 'synthetic-pack',
          ),
          throwsArgumentError,
        );
      }
    });
  });
}
