import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/widgets/labelled.dart';

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

/// The only widget that draws or speaks a surah name read from a pack
/// (D-084, D-160).
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

  /// [child] named for a screen reader by [template], an ARB template that
  /// takes the name, filled with [name] in [format] (D-160). The label is
  /// made and set here, so the name never leaves this file as a string; the
  /// child's own semantics are dropped, and with [onTap] it is a button.
  static Widget labelled(
    PackText name, {
    required String Function(String name) template,
    required Widget child,
    SurahNameFormat format = SurahNameFormat.titled,
    String? value,
    VoidCallback? onTap,
  }) {
    assert(
      format == SurahNameFormat.name || format == SurahNameFormat.titled,
      'A label names the surah, without an ayah.',
    );
    return _LabelledSurah(
      name: name,
      format: format,
      template: template,
      value: value,
      onTap: onTap,
      child: child,
    );
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

final class _LabelledSurah extends StatelessWidget {
  const _LabelledSurah({
    required this.name,
    required this.format,
    required this.template,
    required this.child,
    this.value,
    this.onTap,
  });

  final PackText name;
  final SurahNameFormat format;
  final String Function(String name) template;
  final Widget child;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => labelled(
    label: template(_written(name, format, null, AppLocalizations.of(context))),
    value: value,
    onTap: onTap,
    child: child,
  );
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
