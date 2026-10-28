import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';

/// The ways a surah name is written (D-084, D-130).
enum SurahNameFormat {
  /// The name alone.
  name,

  /// «سورة» before the name (`surahTitle`).
  titled,

  /// The name with an ayah number (`surahAyahReference`).
  withAyah,

  /// «سورة» before the name, with an ayah number (`surahTitleAyahReference`).
  titledWithAyah,

  /// The reference that ends the full copy format, from the space after the
  /// closing bracket (`copyReferenceFull`, Share.dc.html l.54).
  copyReference,
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
                 format == SurahNameFormat.titledWithAyah ||
                 format == SurahNameFormat.copyReference),
       );

  /// [name] in [format] as a span set inline in another paragraph, as the
  /// copy sheet's preview sets its reference after the quoted ayah (D-130).
  /// [style] does not inherit, so nothing of that paragraph's style, such as
  /// the Quran font, reaches the name.
  static SurahNameSpan span(
    PackText name, {
    required SurahNameFormat format,
    required TextStyle style,
    required AppLocalizations l10n,
    int? ayah,
  }) {
    assert(
      (ayah != null) ==
          (format == SurahNameFormat.withAyah ||
              format == SurahNameFormat.titledWithAyah ||
              format == SurahNameFormat.copyReference),
    );
    assert(!style.inherit, 'The span would take the paragraph style.');
    return SurahNameSpan._(_written(name, format, ayah, l10n), style);
  }

  final PackText name;
  final TextStyle style;
  final SurahNameFormat format;
  final int? ayah;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final text = _written(name, format, ayah, AppLocalizations.of(context));
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

/// A surah name from a pack in one of its formats, made only by
/// [SurahName.span], in its own style.
final class SurahNameSpan extends TextSpan {
  const SurahNameSpan._(String text, TextStyle style)
    : super(text: text, style: style);
}

String _written(
  PackText name,
  SurahNameFormat format,
  int? ayah,
  AppLocalizations l10n,
) {
  final value = name.verbatim;
  return switch (format) {
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
    SurahNameFormat.copyReference => l10n.copyReferenceFull(
      value,
      arabicDigits(ayah!),
    ),
  };
}

const Locale _arabic = Locale('ar');
