import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/catalogue.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/install_job.dart';
import 'package:holyquran/domain/models/pack_manifest.dart';
import 'package:holyquran/domain/models/recitation.dart';

RemoteFile _remote(String name) => RemoteFile(
  url: Uri.parse('https://example.invalid/$name'),
  sha256: 'a' * 64,
  bytes: 10,
);

CatalogueEntry _pack(String id, PackKind kind, {CatalogueRole? role}) =>
    CatalogueEntry(
      id: id,
      kind: kind,
      version: 1,
      title: 'Synthetic title',
      manifest: _remote('manifest.json'),
      signature: null,
      files: {'data.sqlite': _remote('data.sqlite')},
      source: 'Synthetic source',
      changes: 'Synthetic changes',
      role: role,
    );

CatalogueRecitation _recitation(
  String id,
  String packId, {
  bool rightsComplete = true,
}) => CatalogueRecitation(
  recitation: Recitation(
    id: id,
    reciter: 'Synthetic reciter',
    riwaya: 'hafs',
    style: 'Synthetic style',
    unit: RecitationUnit.ayah,
    hasWordTiming: false,
    rightsComplete: rightsComplete,
  ),
  qualities: [64],
  packId: packId,
);

void main() {
  final text = _pack('synthetic-text', PackKind.text);
  final tafsir = _pack(
    'synthetic-tafsir',
    PackKind.tafsir,
    role: CatalogueRole.firstUseTafsir,
  );
  final audioA = _pack('synthetic-audio-a', PackKind.recitation);
  final audioB = _pack('synthetic-audio-b', PackKind.recitation);

  test('finds packs by id and the first-use tafsir', () {
    final catalogue = Catalogue(
      date: '2026-10-12',
      packs: [text, tafsir],
      recitations: [],
    );
    expect(catalogue.date, '2026-10-12');
    expect(catalogue.pack('synthetic-text'), same(text));
    expect(catalogue.pack('synthetic-none'), isNull);
    expect(catalogue.firstUseTafsir, same(tafsir));
    expect(
      Catalogue(
        date: '2026-10-12',
        packs: [text],
        recitations: [],
      ).firstUseTafsir,
      isNull,
    );
    expect(() => catalogue.packs.add(text), throwsUnsupportedError);
  });

  test('lists only the recitations whose rights record is complete', () {
    final listed = _recitation('synthetic-listed', audioA.id);
    final pending = _recitation(
      'synthetic-pending',
      audioB.id,
      rightsComplete: false,
    );
    final catalogue = Catalogue(
      date: '2026-10-12',
      packs: [audioA, audioB],
      recitations: [listed, pending],
    );
    expect(catalogue.recitations, [listed, pending]);
    expect(catalogue.listedRecitations, [listed]);
  });

  test('refuses an inconsistent catalogue', () {
    for (final (packs, recitations) in [
      ([text, text], <CatalogueRecitation>[]),
      (
        [tafsir, _pack('synthetic-other', PackKind.tafsir, role: tafsir.role)],
        <CatalogueRecitation>[],
      ),
      ([text], [_recitation('synthetic-r', 'synthetic-none')]),
      ([text], [_recitation('synthetic-r', text.id)]),
      (
        [audioA, audioB],
        [
          _recitation('synthetic-r', audioA.id),
          _recitation('synthetic-r', audioB.id),
        ],
      ),
      (
        [audioA],
        [
          _recitation('synthetic-r', audioA.id),
          _recitation('synthetic-s', audioA.id),
        ],
      ),
    ]) {
      expect(
        () => Catalogue(
          date: '2026-10-12',
          packs: packs,
          recitations: recitations,
        ),
        throwsArgumentError,
      );
    }
  });

  test('every failure names itself', () {
    final url = Uri.parse('https://example.invalid/catalogue.json');
    expect(
      '${CatalogueUnreachable(url, 'offline')}',
      'CatalogueUnreachable($url): offline',
    );
    expect('${const CatalogueRejected('why')}', 'CatalogueRejected: why');
    expect(
      '${const CatalogueUnsupported(2)}',
      'CatalogueUnsupported: version 2',
    );
    expect(
      '${const CatalogueSignatureRejected()}',
      'CatalogueSignatureRejected',
    );
    expect(
      '${const CatalogueSignatureNotChecked()}',
      'CatalogueSignatureNotChecked',
    );
  });
}
