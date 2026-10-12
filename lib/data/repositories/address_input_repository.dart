import '../../domain/models/surah_info.dart';
import '../../utils/result.dart';
import '../services/surah_name_index.dart';

/// What typed addresses need from the packs beyond the edition's structure.
abstract interface class AddressInputRepository {
  /// The number of the surah whose stored name is [name], `Ok(null)` when
  /// none is; a failure when the surahs cannot be read.
  Future<Result<int?>> surahNamed(String name);
}

/// Matches names against the surahs of the text pack, read once.
final class PackAddressInputRepository implements AddressInputRepository {
  /// `surahs` reads the surah list, such as `QuranTextRepository.surahs`. A
  /// failed read is returned and tried again on the next call.
  PackAddressInputRepository({required this._surahs});

  final Future<Result<List<SurahInfo>>> Function() _surahs;

  /// The index once read, or the read in flight, which concurrent first calls
  /// share.
  Future<Result<SurahNameIndex>>? _index;

  @override
  Future<Result<int?>> surahNamed(String name) async {
    final index = _index ??= _read();
    switch (await index) {
      case Ok(:final value):
        return Ok(value.surahNamed(name));
      case Failure(:final error):
        if (identical(_index, index)) _index = null;
        return Failure(error);
    }
  }

  Future<Result<SurahNameIndex>> _read() async => switch (await _surahs()) {
    Ok(:final value) => Ok(SurahNameIndex(value)),
    Failure(:final error) => Failure(error),
  };
}
