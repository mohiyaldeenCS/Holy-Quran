import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';

/// The ways a surah name is written (D-084).
enum SurahNameFormat {
  /// The name alone.
  name,

  /// «سورة» before the name (`surahTitle`).
  titled,

  /// The name with an ayah number (`surahAyahReference`).
  withAyah,

  /// «سورة» before the name, with an ayah number (`surahTitleAyahReference`).
  titledWithAyah,
}

/// The only widget that draws a surah name read from a pack (D-084).
///
/// [name] is substituted whole and unchanged into the ARB template of
/// [format]; [ayah] is required by the formats that carry one and written in
/// Arabic-Indic digits. The name is never truncated: it wraps.
final class SurahName extends StatelessWidget {
  const SurahName(
    this.name, {
    required this.style,
    this.format = SurahNameFormat.name,
    this.ayah,
    this.textAlign = TextAlign.start,
    super.key,
  }) : assert(
         (ayah != null) ==
             (format == SurahNameFormat.withAyah ||
                 format == SurahNameFormat.titledWithAyah),
       );

  final PackText name;
  final TextStyle style;
  final SurahNameFormat format;
  final int? ayah;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = name.verbatim;
    final text = switch (format) {
      SurahNameFormat.name => value,
      SurahNameFormat.titled => l10n.surahTitle(value),
      SurahNameFormat.withAyah => l10n.surahAyahReference(
        value,
        arabicDigits(ayah!),
      ),
      SurahNameFormat.titledWithAyah => l10n.surahTitleAyahReference(
        value,
        arabicDigits(ayah!),
      ),
    };
    // A fresh DefaultTextStyle drops an ambient line limit or ellipsis.
    return DefaultTextStyle(
      style: DefaultTextStyle.of(context).style,
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        textDirection: TextDirection.rtl,
        locale: _arabic,
      ),
    );
  }
}

const Locale _arabic = Locale('ar');
