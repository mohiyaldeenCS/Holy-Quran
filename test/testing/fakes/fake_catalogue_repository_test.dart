import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/catalogue.dart';
import 'package:holyquran/utils/result.dart';

import '../../../testing/fakes/fake_catalogue_repository.dart';

void main() {
  test('the synthetic catalogue parses, with one recitation listed', () {
    final catalogue = syntheticCatalogue(tafsirVersion: 5);
    expect(catalogue.packs, hasLength(4));
    expect(catalogue.firstUseTafsir!.version, 5);
    expect(catalogue.recitations, hasLength(2));
    expect(
      [for (final r in catalogue.listedRecitations) r.id],
      ['synthetic-listed'],
    );
    expect(syntheticHash(), hasLength(64));
  });

  test('the fake serves what the test sets and notifies', () async {
    final fake = FakeCatalogueRepository();
    addTearDown(fake.dispose);
    var notified = 0;
    fake.addListener(() => notified++);
    expect(fake.catalogue, isNull);

    expect(await fake.refresh(), isA<Failure<Catalogue>>());
    expect(fake.catalogue, isNull);

    final catalogue = syntheticCatalogue();
    fake.refreshes = () => Ok(catalogue);
    expect(await fake.refresh(), isA<Ok<Catalogue>>());
    expect(fake.catalogue, same(catalogue));
    expect(fake.refreshCount, 2);
    expect(notified, 1);

    fake.catalogue = null;
    expect(notified, 2);
    expect(FakeCatalogueRepository(catalogue).catalogue, same(catalogue));
  });
}
