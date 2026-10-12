import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';
import 'package:holyquran/utils/command.dart';
import 'package:holyquran/utils/result.dart';

/// Hands a PNG image to the system share sheet; the composition root gives
/// the share service's.
typedef ShareImage =
    Future<Result<void>> Function(Uint8List png, {required String fileName});

/// Paints the chosen card; the view gives it, as painting needs the screen.
typedef PaintCard = Future<Uint8List> Function();

/// The share sheet of the ayah at [address] (SH-02): the ayah and its
/// surah's name read from the pack by the address (SH-05), the design
/// chosen, and [share], which hands the painted card to the share sheet.
final class ShareCardSheetViewModel extends ChangeNotifier {
  ShareCardSheetViewModel({
    required QuranAddress address,
    required this._repository,
    required this._shareImage,
  }) : address = address.ayahAddress {
    load = Command0(_load)..execute();
    share = Command1(_share);
  }

  final QuranAddress address;
  final QuranTextRepository _repository;
  final ShareImage _shareImage;

  late final Command0<void> load;
  late final Command1<void, PaintCard> share;

  PackText? _ayah;
  PackText? _surahName;
  ShareCardDesign _design = ShareCardDesign.emerald;

  /// The ayah, once [load] has read it.
  PackText? get ayah => _ayah;

  /// The ayah's surah name, once [load] has read it.
  PackText? get surahName => _surahName;

  ShareCardDesign get design => _design;

  void selectDesign(ShareCardDesign design) {
    if (design == _design) return;
    _design = design;
    notifyListeners();
  }

  Future<Result<void>> _load() async {
    final PackText ayah;
    switch (await _repository.ayahText(address)) {
      case Ok(:final value):
        ayah = value;
      case Failure(:final error):
        return Failure(error);
    }
    switch (await _repository.surahs()) {
      case Ok(:final value):
        for (final surah in value) {
          if (surah.number == address.surah) {
            _ayah = ayah;
            _surahName = surah.name;
            notifyListeners();
            return const Ok(null);
          }
        }
        return Failure(AddressNotInPack(_repository.riwaya, address));
      case Failure(:final error):
        return Failure(error);
    }
  }

  Future<Result<void>> _share(PaintCard paint) async => _shareImage(
    await paint(),
    fileName: '${address.riwaya}-${address.surah}-${address.ayah}.png',
  );

  @override
  void dispose() {
    load.dispose();
    share.dispose();
    super.dispose();
  }
}
