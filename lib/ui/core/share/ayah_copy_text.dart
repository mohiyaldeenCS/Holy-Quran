import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/domain/models/copy_form.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/utils/result.dart';

/// The text an ayah is copied as (SH-01), read from the pack by its address
/// at the moment of copying, never from what a widget shows (SH-05).
///
/// A pack-text sink of D-114: the ayah and its surah's name enter the ARB
/// format whole and unchanged.
final class AyahCopyText {
  const AyahCopyText(this._repository, this._l10n);

  final QuranTextRepository _repository;
  final AppLocalizations _l10n;

  /// The forms whose format the ARB file gives, in [CopyForm]'s order.
  List<CopyForm> get forms => [
    for (final form in CopyForm.values)
      if (_formatOf(form) != null) form,
  ];

  /// The copied text of the ayah at [address] in [form].
  Future<Result<String>> compose(QuranAddress address, CopyForm form) async {
    final format = _formatOf(form);
    if (format == null) return Failure(CopyFormUnavailable(form));
    return switch (await _read(address)) {
      Ok(value: (:final ayah, :final surahName, :final number)) => Ok(
        format(ayah.verbatim, surahName.verbatim, arabicDigits(number)),
      ),
      Failure(:final error) => Failure(error),
    };
  }

  /// The parts the copy sheet previews of the ayah at [address] in [form],
  /// as the pack holds them: `QuranText.quoted` sets the ayah between the
  /// format's brackets and `SurahName.span` the reference after it (D-130).
  /// The full form, the only one offered, has the surah's name and the
  /// ayah's number in its reference.
  Future<Result<CopyPreview>> preview(
    QuranAddress address,
    CopyForm form,
  ) async {
    if (_formatOf(form) == null) return Failure(CopyFormUnavailable(form));
    return switch (await _read(address)) {
      Ok(value: (:final ayah, :final surahName, :final number)) => Ok((
        ayah: ayah,
        surahName: surahName,
        ayahNumber: number,
      )),
      Failure(:final error) => Failure(error),
    };
  }

  Future<Result<_Parts>> _read(QuranAddress address) async {
    final ayahAddress = address.ayahAddress;
    final PackText ayah;
    switch (await _repository.ayahText(ayahAddress)) {
      case Ok(:final value):
        ayah = value;
      case Failure(:final error):
        return Failure(error);
    }
    final List<SurahInfo> surahs;
    switch (await _repository.surahs()) {
      case Ok(:final value):
        surahs = value;
      case Failure(:final error):
        return Failure(error);
    }
    for (final surah in surahs) {
      if (surah.number == ayahAddress.surah) {
        return Ok((
          ayah: ayah,
          surahName: surah.name,
          number: ayahAddress.ayah,
        ));
      }
    }
    return Failure(AddressNotInPack(_repository.riwaya, ayahAddress));
  }

  // The full form only, until the formats of Appendix B are approved
  // (docs/plans/PHASE1.md, P1-38).
  _CopyFormat? _formatOf(CopyForm form) => switch (form) {
    CopyForm.withSurahAndNumber => _l10n.copyFormatFull,
    CopyForm.ayahOnly || CopyForm.withSurah => null,
  };
}

/// The parts of the copy sheet's preview of a form, from the pack: the ayah,
/// whole, and, for a form with a reference, its surah's name and the ayah's
/// number.
typedef CopyPreview = ({PackText ayah, PackText? surahName, int? ayahNumber});

typedef _Parts = ({PackText ayah, PackText surahName, int number});

typedef _CopyFormat = String Function(String ayah, String surah, String number);

/// A copy form whose format the ARB file does not give yet.
final class CopyFormUnavailable implements Exception {
  const CopyFormUnavailable(this.form);

  final CopyForm form;

  @override
  String toString() => 'CopyFormUnavailable(${form.name})';
}
