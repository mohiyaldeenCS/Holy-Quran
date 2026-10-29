import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The only widget that draws text of a tafsir book read from a pack
/// (`TF-08`): a passage, or a fact of the book such as its title.
///
/// [text] is drawn whole and unchanged in the interface font, in [style]
/// (`tafsir` by default) and `ink`. An ayah quoted inside a passage is part
/// of the source's text: nothing in here is Quran text, and none of it takes
/// the Quran font or its colour.
final class TafsirText extends StatelessWidget {
  const TafsirText(
    this.text, {
    this.style = AppTextStyles.tafsir,
    this.color,
    this.format,
    super.key,
  });

  /// [text] set inline in another paragraph, as the source badge sets its
  /// title before the version. [style] does not inherit, so the paragraph
  /// takes nothing of it and it takes nothing of the paragraph.
  static TafsirTextSpan span(PackText text, {required TextStyle style}) {
    assert(!style.inherit, 'The span would take the paragraph style.');
    return TafsirTextSpan._(text.verbatim, style);
  }

  final PackText text;
  final TextStyle style;

  /// `ink` when null.
  final Color? color;

  /// An ARB template with the text as its one placeholder, such as «الناشر:
  /// {publisher}»; the text enters it whole and unchanged. Null draws the text
  /// alone.
  final String Function(String text)? format;

  @override
  Widget build(BuildContext context) => Text(
    format?.call(text.verbatim) ?? text.verbatim,
    style: style.copyWith(color: color ?? context.colors.ink),
    textDirection: TextDirection.rtl,
    locale: _arabic,
  );
}

/// Tafsir text from a pack in its own style, made only by [TafsirText.span].
final class TafsirTextSpan extends TextSpan {
  const TafsirTextSpan._(String text, TextStyle style)
    : super(text: text, style: style);
}

const Locale _arabic = Locale('ar');
