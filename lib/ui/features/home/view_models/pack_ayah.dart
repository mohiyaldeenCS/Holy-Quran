import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';

/// Whether [address] is an ayah of the pack [index] serves: a saved position
/// may be of another riwaya or edition than the one installed now.
bool isAyahOfPack(QuranIndexRepository index, QuranAddress address) {
  final surahs = index.surahs;
  return address.riwaya == index.riwaya &&
      address.surah >= 1 &&
      address.surah <= surahs.length &&
      address.ayah >= 1 &&
      address.ayah <= surahs[address.surah - 1].ayahCount;
}
