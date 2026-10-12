import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/address_input_repository.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/utils/result.dart';

final class _ReadFailed implements Exception {
  const _ReadFailed();
}

/// A surah list source that counts its reads and fails while [failing].
final class _Surahs {
  var reads = 0;
  var failing = false;

  Future<Result<List<SurahInfo>>> call() async {
    reads++;
    if (failing) return const Failure(_ReadFailed());
    return const Ok([
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
  }
}

Object? _value(Result<int?> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => error,
};

void main() {
  late _Surahs surahs;
  late PackAddressInputRepository repository;

  setUp(() {
    surahs = _Surahs();
    repository = PackAddressInputRepository(surahs: surahs.call);
  });

  test('finds a surah by its stored name, null for any other', () async {
    expect(_value(await repository.surahNamed('Synthetic two')), 2);
    expect(_value(await repository.surahNamed('Synthetic one')), 1);
    expect(_value(await repository.surahNamed('Synthetic')), isNull);
  });

  test('reads the surahs once', () async {
    await repository.surahNamed('Synthetic one');
    await repository.surahNamed('Synthetic two');
    await repository.surahNamed('none');
    expect(surahs.reads, 1);
  });

  test('concurrent first calls share one read', () async {
    final results = await Future.wait([
      repository.surahNamed('Synthetic one'),
      repository.surahNamed('Synthetic two'),
    ]);
    expect(results.map(_value), [1, 2]);
    expect(surahs.reads, 1);
  });

  test('returns a failed read and reads again on the next call', () async {
    surahs.failing = true;
    expect(
      _value(await repository.surahNamed('Synthetic one')),
      const _ReadFailed(),
    );
    surahs.failing = false;
    expect(_value(await repository.surahNamed('Synthetic one')), 1);
    expect(surahs.reads, 2);
  });
}
