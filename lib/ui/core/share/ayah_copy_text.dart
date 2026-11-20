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
  const AyahCopyText(
    this._repository,
    this._l10n, {
    this.unapprovedCopy = false,
  });

  final QuranTextRepository _repository;
  final AppLocalizations _l10n;

  /// In the unapproved test copy the copied text ends with a line saying so,
  /// after the copy exactly as an approved build composes it (D-162 (14)).
  final bool unapprovedCopy;

  /// The copied text of the ayah at [address] in [form].
  Future<Result<String>> compose(QuranAddress address, CopyForm form) async =>
      switch (await _read(address)) {
        Ok(:final value) => Ok(_marked(_formatted(form, value))),
        Failure(:final error) => Failure(error),
      };

  String _formatted(CopyForm form, _Parts parts) {
    final ayah = parts.ayah.verbatim;
    final surah = parts.surahName.verbatim;
    return switch (form) {
      CopyForm.ayahOnly => _l10n.copyFormatAyahOnly(ayah),
      CopyForm.withSurah => _l10n.copyFormatWithSurah(ayah, surah),
      CopyForm.withSurahAndNumber => _l10n.copyFormatFull(
        ayah,
        surah,
        arabicDigits(parts.number),
      ),
    };
  }

  String _marked(String copy) =>
      unapprovedCopy ? '$copy\n${_l10n.unapprovedTestCopy}' : copy;

  /// The parts the copy sheet previews of the ayah at [address] in [form],
  /// as the pack holds them: `QuranText.quoted` sets the ayah between the
  /// format's brackets and `SurahName.span` the reference after it (D-130).
  /// The ayah alone has no reference; the form with the surah's name has no
  /// ayah number in it.
  Future<Result<CopyPreview>> preview(
    QuranAddress address,
    CopyForm form,
  ) async => switch (await _read(address)) {
    Ok(value: (:final ayah, :final surahName, :final number)) => Ok(
      switch (form) {
        CopyForm.ayahOnly => (ayah: ayah, surahName: null, ayahNumber: null),
        CopyForm.withSurah => (
          ayah: ayah,
          surahName: surahName,
          ayahNumber: null,
        ),
        CopyForm.withSurahAndNumber => (
          ayah: ayah,
          surahName: surahName,
          ayahNumber: number,
        ),
      },
    ),
    Failure(:final error) => Failure(error),
  };

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
}

/// The parts of the copy sheet's preview of a form, from the pack: the ayah,
/// whole, its surah's name for a form with a reference, and the ayah's number
/// for the full form.
typedef CopyPreview = ({PackText ayah, PackText? surahName, int? ayahNumber});

typedef _Parts = ({PackText ayah, PackText surahName, int number});
