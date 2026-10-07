import 'dart:convert';
import 'dart:typed_data';

import 'gibberish.dart';

/// A sura of a synthetic Tanzil-form XML fixture. Every value is synthetic.
typedef FixtureSura = ({String name, String? bismillah, List<String> ayat});

const fixtureNotice =
    '\n# Synthetic notice for tests, not a licence\n#  line two\t\n';

/// Bytes in the Tanzil XML form, with [notice] as the one comment before the
/// root element, or after it when [noticeLast].
Uint8List tanzilFixtureXml(
  List<FixtureSura> suras, {
  String notice = fixtureNotice,
  bool noticeLast = false,
}) {
  String attribute(String name, String value) {
    if (RegExp('["<&\t\n\r]').hasMatch(value)) {
      throw ArgumentError.value(name, 'value', 'cannot be quoted verbatim');
    }
    return ' $name="$value"';
  }

  final comment = '<!--$notice-->\n';
  final out = StringBuffer('<?xml version="1.0" encoding="utf-8" ?>\n');
  if (!noticeLast) out.write(comment);
  out.write('<quran>\n');
  for (final (s, sura) in suras.indexed) {
    out.write(
      '\t<sura${attribute('index', '${s + 1}')}'
      '${attribute('name', sura.name)}>\n',
    );
    for (final (a, text) in sura.ayat.indexed) {
      out.write(
        '\t\t<aya${attribute('index', '${a + 1}')}'
        '${attribute('text', text)}',
      );
      if (a == 0 && sura.bismillah != null) {
        out.write(attribute('bismillah', sura.bismillah!));
      }
      out.write(' />\n');
    }
    out.write('\t</sura>\n');
  }
  out.write('</quran>\n');
  if (noticeLast) out.write('\n$comment');
  return utf8.encode(out.toString());
}

/// Three synthetic suras that any change of bytes would break: NFC-unstable
/// text, leading, trailing and double spaces, a character outside the BMP,
/// Arabic-script nonsense, and suras with and without a bismillah.
List<FixtureSura> syntheticFixtureSuras({int seed = 1}) {
  final nonsense = SyntheticArabicScript(seed);
  return [
    (
      name: nonsense.word(),
      bismillah: null,
      ayat: [
        'Synthetic e\u{301} one',
        'Synthetic \u{E9} two',
        nonsense.phrase(7),
        nonsense.phrase(3),
      ],
    ),
    (
      name: nonsense.word(),
      bismillah: nonsense.phrase(4),
      ayat: [
        ' Synthetic  double  spaces ',
        'ab \u{1F600} cd',
        nonsense.phrase(12),
      ],
    ),
    (
      name: 'Synthetic sura three',
      bismillah: nonsense.phrase(4),
      ayat: [nonsense.phrase(2)],
    ),
  ];
}
