import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/address_providers.dart';
import 'package:holyquran/data/repositories/address_input_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/utils/result.dart';

final class _Text implements QuranTextRepository {
  @override
  Future<Result<List<SurahInfo>>> surahs() async => const Ok([
    SurahInfo(
      number: 1,
      name: PackText.fromPack('Synthetic one'),
      ayahCount: 3,
    ),
    SurahInfo(
      number: 2,
      name: PackText.fromPack('Synthetic two'),
      ayahCount: 4,
    ),
  ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('provides nothing without the base pack text', () async {
    expect(await buildDependencies(areas: [addressProviders]), isEmpty);
  });

  test('matches names against the surahs of the base pack text', () async {
    late AddressInputRepository addresses;
    await buildDependencies(
      areas: [
        (dependencies) async =>
            dependencies.provide<QuranTextRepository>(_Text()),
        addressProviders,
        (dependencies) async =>
            addresses = dependencies.read<AddressInputRepository>(),
      ],
    );

    expect(switch (await addresses.surahNamed('Synthetic two')) {
      Ok(:final value) => value,
      Failure(:final error) => error,
    }, 2);
  });
}
