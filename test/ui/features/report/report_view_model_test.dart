import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/features/report/view_models/report_view_model.dart';

import '../../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../../testing/fakes/fake_quran_index_repository.dart';
import 'report_test_support.dart';

void main() {
  late Directory root;
  late InstalledPack tafsir;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('report_view_model_test');
    tafsir = await installedSyntheticTafsir(root);
  });

  tearDownAll(() => root.delete(recursive: true));

  final address = QuranAddress('hafs', 2, 3);

  test('names the ayah by its surah in the index', () {
    final index = FakeQuranIndexRepository.synthetic();
    final viewModel = ReportViewModel(address: address, index: index);
    addTearDown(viewModel.dispose);

    expect(viewModel.surahName, same(index.surahs[1].name));
    expect(viewModel.pack, isNull);
    expect(viewModel.report, ErrorReport(address: address));
  });

  test('hides the name of an ayah the index does not hold', () {
    final index = FakeQuranIndexRepository.synthetic();
    for (final missing in [
      QuranAddress('hafs', 2, 4),
      QuranAddress('hafs', 9, 1),
      QuranAddress('warsh', 2, 3),
    ]) {
      final viewModel = ReportViewModel(address: missing, index: index);
      addTearDown(viewModel.dispose);
      expect(viewModel.surahName, isNull, reason: '$missing');
    }
    final noIndex = ReportViewModel(address: address);
    addTearDown(noIndex.dispose);
    expect(noIndex.surahName, isNull);
  });

  test('composes a report on an entry from the installed manifest', () {
    final viewModel = ReportViewModel(
      address: address,
      packId: tafsir.id,
      packs: FakePackInstallRepository(installed: [tafsir]),
    );
    addTearDown(viewModel.dispose);

    expect(viewModel.pack?.id, tafsir.manifest.id);
    expect(viewModel.pack?.version, tafsir.manifest.version);
    expect(viewModel.pack?.sourceName, tafsir.manifest.sources.first.name);
    expect(
      viewModel.report,
      ErrorReport(
        address: address,
        packId: tafsir.manifest.id,
        packVersion: tafsir.manifest.version,
        sourceName: tafsir.manifest.sources.first.name,
      ),
    );
  });

  test('leaves out a pack that is not installed', () {
    final packs = FakePackInstallRepository();
    final viewModel = ReportViewModel(
      address: address,
      packId: tafsir.id,
      packs: packs,
    );
    addTearDown(viewModel.dispose);

    expect(viewModel.pack, isNull);
    expect(viewModel.report, ErrorReport(address: address));

    var notified = 0;
    viewModel.addListener(() => notified++);
    packs.installed = [tafsir];

    expect(notified, 1);
    expect(viewModel.pack?.id, tafsir.id);
  });
}
