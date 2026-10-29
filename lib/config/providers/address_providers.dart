import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/repositories/address_input_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';

/// Provides the [AddressInputRepository] that matches typed surah names
/// against the base pack's surahs. Without a verified base pack, which
/// provides the text, there are no names to match and nothing is provided.
Future<void> addressProviders(Dependencies dependencies) async {
  if (dependencies.tryRead<QuranTextRepository>() case final text?) {
    dependencies.provide<AddressInputRepository>(
      PackAddressInputRepository(surahs: text.surahs),
    );
  }
}
