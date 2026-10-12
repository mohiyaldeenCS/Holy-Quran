import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/ui/core/share/share_card_sheet_view_model.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';
import 'package:holyquran/utils/result.dart';

import '../../../integrity/pack_integrity_suite.dart';
import 'share_test_pack.dart';

typedef _Shared = ({Uint8List png, String fileName});

void main() {
  late PackUnderTest pack;

  setUpAll(() async {
    pack = await loadShareTestPack();
  });

  ShareCardSheetViewModel viewModel(
    QuranAddress Function(String riwaya) address,
    List<_Shared> shared,
  ) {
    final repository = pack.openRepository();
    return ShareCardSheetViewModel(
      address: address(repository.riwaya),
      repository: repository,
      shareImage: (png, {required fileName}) async {
        shared.add((png: png, fileName: fileName));
        return const Ok(null);
      },
    );
  }

  Future<void> loaded(ShareCardSheetViewModel model) async {
    while (model.load.running || model.load.result == null) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('reads the ayah and its surah name from the pack by address', () async {
    final model = viewModel((riwaya) => QuranAddress(riwaya, 2, 3, 1), []);
    addTearDown(model.dispose);
    await loaded(model);
    expect(model.load.completed, isTrue);
    final repository = pack.openRepository();
    final address = QuranAddress(repository.riwaya, 2, 3);
    expect(model.address, address);
    expect(model.ayah, (await repository.ayahText(address) as Ok).value);
    final surahs = (await repository.surahs() as Ok<List<SurahInfo>>).value;
    expect(model.surahName, surahs.singleWhere((s) => s.number == 2).name);
  });

  test('starts on the emerald design and switches', () {
    final model = viewModel((riwaya) => QuranAddress(riwaya, 1, 1), []);
    addTearDown(model.dispose);
    var notified = 0;
    model.addListener(() => notified++);
    expect(model.design, ShareCardDesign.emerald);
    model
      ..selectDesign(ShareCardDesign.night)
      ..selectDesign(ShareCardDesign.night);
    expect(model.design, ShareCardDesign.night);
    expect(notified, 1);
  });

  test('a failed read leaves nothing to show', () async {
    final model = viewModel((riwaya) => QuranAddress(riwaya, 1, 99), []);
    addTearDown(model.dispose);
    await loaded(model);
    expect(
      (model.load.result! as Failure<void>).error,
      isA<AddressNotInPack>(),
    );
    expect(model.ayah, isNull);
    expect(model.surahName, isNull);
  });

  test('shares what the view paints, named by the address', () async {
    final shared = <_Shared>[];
    final model = viewModel((riwaya) => QuranAddress(riwaya, 3, 1), shared);
    addTearDown(model.dispose);
    final png = Uint8List.fromList([1, 2, 3]);
    await model.share.execute(() async => png);
    expect(model.share.completed, isTrue);
    expect(shared.single.png, same(png));
    expect(shared.single.fileName, '${model.address.riwaya}-3-1.png');
  });
}
