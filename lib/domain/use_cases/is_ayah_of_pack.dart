import '../models/quran_address.dart';
import '../models/surah_info.dart';

/// Whether [address] is an ayah of the pack whose riwaya is [riwaya] and
/// whose surahs are [surahs]: a saved position may be of another riwaya or
/// edition than the one installed now. A pack that serves no surahs has no
/// ayah.
bool isAyahOfPack(
  QuranAddress address, {
  required String riwaya,
  required List<SurahInfo> surahs,
}) =>
    address.riwaya == riwaya &&
    address.surah >= 1 &&
    address.surah <= surahs.length &&
    address.ayah >= 1 &&
    address.ayah <= surahs[address.surah - 1].ayahCount;
