@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/tafsir/source_details_sheet.dart';
import 'package:holyquran/ui/features/tafsir/view_models/tafsir_view_model.dart';

import '../../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../../testing/golden.dart';
import '../resources/resources_fixtures.dart';
import 'tafsir_fixture.dart';
import 'tafsir_harness.dart';

// The reader, the sheet and the source details in the four themes, over the
// synthetic pack: a passage over three ayat, two books downloaded and the
// catalogue's others available.

void main() {
  const phone = Size(360, 800);

  Future<void> draw(
    WidgetTester tester,
    String name,
    Widget Function(TafsirViewModel) build,
  ) async {
    final fixture = (await tester.runAsync(TafsirFixture.open))!;
    try {
      await tester.runAsync(() => fixture.install(id: 'synthetic-tafsir-b'));
      final catalogue = FakeCatalogueRepository(catalogueWith());
      addTearDown(catalogue.dispose);
      final model = await openModel(
        tester,
        fixture,
        QuranAddress(fixture.quran.riwaya, 1, 2),
        catalogue: catalogue,
      );
      await expectGoldensInThemes(
        tester,
        name,
        (context) => build(model),
        surfaceSize: phone,
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(fixture.close);
    }
  }

  testWidgets('the reader', (tester) async {
    await draw(
      tester,
      'tafsir_reader',
      (model) => SizedBox.fromSize(size: phone, child: reader(model)),
    );
  });

  testWidgets('the sheet', (tester) async {
    await draw(
      tester,
      'tafsir_sheet',
      (model) => SizedBox.fromSize(
        size: phone,
        child: Align(alignment: Alignment.bottomCenter, child: sheetOf(model)),
      ),
    );
  });

  testWidgets('the source details', (tester) async {
    await draw(
      tester,
      'tafsir_source_details',
      (model) => SizedBox(
        width: phone.width,
        height: phone.height,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SourceDetailsSheet(page: model.page!),
        ),
      ),
    );
  });
}
