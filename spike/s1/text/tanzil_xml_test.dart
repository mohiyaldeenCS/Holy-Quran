import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'tanzil_fixture.dart';
import 'tanzil_xml.dart';

// Every value is synthetic; non-ASCII characters are written as escapes.

const _head = '<?xml version="1.0" encoding="utf-8" ?>\n<!-- n -->\n';

Uint8List _xml(String body, {String head = _head}) => utf8.encode('$head$body');

const _oneAya =
    '<quran><sura index="1" name="S"><aya index="1" text="T"/>'
    '</sura></quran>';

void main() {
  group('readTanzilXml reads', () {
    final suras = syntheticFixtureSuras();
    final bytes = tanzilFixtureXml(suras);
    final xml = readTanzilXml(bytes);

    test('every sura and aya in order, numbered from 1', () {
      expect([for (final s in xml.suras) s.index], [1, 2, 3]);
      expect(
        [for (final a in xml.ayat) (a.surah, a.ayah)],
        [
          for (final (s, sura) in suras.indexed)
            for (var a = 0; a < sura.ayat.length; a++) (s + 1, a + 1),
        ],
      );
    });

    test('every value as the bytes given, at its offset', () {
      void expectAt(String value, int offset, String given) {
        final encoded = utf8.encode(value);
        expect(encoded, utf8.encode(given));
        expect(bytes.sublist(offset, offset + encoded.length), encoded);
      }

      for (final (s, sura) in suras.indexed) {
        final read = xml.suras[s];
        expectAt(read.name, read.nameByteOffset, sura.name);
        final ayat = xml.ayat.where((a) => a.surah == s + 1).toList();
        for (final (a, ayah) in ayat.indexed) {
          expectAt(ayah.text, ayah.byteOffset, sura.ayat[a]);
          if (a == 0 && sura.bismillah != null) {
            expectAt(ayah.basmala!, ayah.basmalaByteOffset!, sura.bismillah!);
          } else {
            expect((ayah.basmala, ayah.basmalaByteOffset), (null, null));
          }
        }
      }
    });

    test('the comment verbatim, wherever it stands outside the root', () {
      expect(utf8.encode(xml.notice), utf8.encode(fixtureNotice));
      final last = tanzilFixtureXml(suras, noticeLast: true);
      final read = readTanzilXml(last);
      expect(utf8.encode(read.notice), utf8.encode(fixtureNotice));
      expect(
        last.sublist(
          read.noticeByteOffset,
          read.noticeByteOffset + utf8.encode(fixtureNotice).length,
        ),
        utf8.encode(fixtureNotice),
      );
    });

    test('single quotes, end tags and no declaration', () {
      final read = readTanzilXml(
        _xml(
          "<quran>\r\n<sura index='1' name='S'><aya index='1' text='T' >"
          '</aya ></sura ></quran>',
          head: '<!--n-->',
        ),
      );
      expect(read.ayat.single.text, 'T');
      expect(read.notice, 'n');
    });
  });

  group('readTanzilXml refuses', () {
    final refusals = <String, Uint8List>{
      'a byte order mark': Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ..._xml(_oneAya),
      ]),
      'malformed UTF-8': _replace(_xml(_oneAya), 'T', [0xC3, 0x28]),
      'an overlong encoding': _replace(_xml(_oneAya), 'T', [0xC0, 0xAF]),
      'an encoded surrogate': _replace(_xml(_oneAya), 'T', [0xED, 0xA0, 0x80]),
      'a value beginning with U+FEFF': _replace(_xml(_oneAya), 'T', [
        0xEF,
        0xBB,
        0xBF,
        0x54,
      ]),
      'U+FFFE in a value': _replace(_xml(_oneAya), 'T', [0xEF, 0xBF, 0xBE]),
      'a control character in a value': _replace(_xml(_oneAya), 'T', [0x01]),
      'an entity reference': _xml(_oneAya.replaceFirst('"T"', '"&amp;"')),
      'a character reference': _xml(_oneAya.replaceFirst('"T"', '"&#65;"')),
      'a reference in content': _xml(
        _oneAya.replaceFirst('</sura>', '&amp;</sura>'),
      ),
      'a CDATA section': _xml(
        _oneAya.replaceFirst('</sura>', '<![CDATA[x]]></sura>'),
      ),
      'a processing instruction': _xml('<?pi x?>$_oneAya'),
      'a stylesheet instruction': _xml('<?xml-stylesheet x?>$_oneAya'),
      'a declaration not at the start': _xml(
        '<?xml version="1.0"?>$_oneAya',
        head: '<!-- n -->',
      ),
      'a DOCTYPE': _xml('<!DOCTYPE quran>$_oneAya'),
      'another encoding': _xml(
        _oneAya,
        head: '<?xml version="1.0" encoding="iso-8859-1"?><!--n-->',
      ),
      'another XML version': _xml(
        _oneAya,
        head: '<?xml version="1.1"?><!--n-->',
      ),
      'an unknown element': _xml(
        _oneAya.replaceFirst('</sura>', '<page/></sura>'),
      ),
      'an element named like a known one': _xml(
        _oneAya.replaceAll('sura', 'surah'),
      ),
      'an unknown aya attribute': _xml(
        _oneAya.replaceFirst('text=', 'type="x" text='),
      ),
      'an unknown sura attribute': _xml(
        _oneAya.replaceFirst('name=', 'ayas="1" name='),
      ),
      'an attribute on quran': _xml(
        _oneAya.replaceFirst('<quran>', '<quran a="1">'),
      ),
      'an uppercase attribute': _xml(_oneAya.replaceFirst('text=', 'Text=')),
      'a repeated attribute': _xml(
        _oneAya.replaceFirst('text="T"', 'text="T" text="T"'),
      ),
      'a missing text': _xml(_oneAya.replaceFirst(' text="T"', '')),
      'a missing name': _xml(_oneAya.replaceFirst(' name="S"', '')),
      'an empty text': _xml(_oneAya.replaceFirst('"T"', '""')),
      'an unquoted value': _xml(_oneAya.replaceFirst('"T"', 'T')),
      'an unterminated value': _xml('<quran><sura index="1" name="S'),
      'a tab in a value': _xml(_oneAya.replaceFirst('"T"', '"T\tT"')),
      'a line break in a value': _xml(_oneAya.replaceFirst('"T"', '"T\nT"')),
      'a carriage return in a value': _xml(
        _oneAya.replaceFirst('"T"', '"T\rT"'),
      ),
      '"<" in a value': _xml(_oneAya.replaceFirst('"T"', '"T<T"')),
      'attributes without space between': _xml(
        _oneAya.replaceFirst('"1" text', '"1"text'),
      ),
      'a sura index gap': _xml(
        _oneAya.replaceFirst('index="1" name', 'index="2" name'),
      ),
      'an aya index gap': _xml(
        _oneAya.replaceFirst('</sura>', '<aya index="3" text="T"/></sura>'),
      ),
      'a leading zero in an index': _xml(
        _oneAya.replaceFirst('aya index="1"', 'aya index="01"'),
      ),
      'a bismillah after aya 1': _xml(
        _oneAya.replaceFirst(
          '</sura>',
          '<aya index="2" text="T" bismillah="B"/></sura>',
        ),
      ),
      'a sura without ayat': _xml(
        '<quran><sura index="1" name="S"></sura></quran>',
      ),
      'an empty sura element': _xml(
        '<quran><sura index="1" name="S"/></quran>',
      ),
      'a quran without suras': _xml('<quran></quran>'),
      'content inside an aya': _xml(
        _oneAya.replaceFirst('text="T"/>', 'text="T">x</aya>'),
      ),
      'character data inside a sura': _xml(
        _oneAya.replaceFirst('</sura>', 'x</sura>'),
      ),
      'a comment inside an element': _xml(
        _oneAya.replaceFirst('</sura>', '<!--c--></sura>'),
      ),
      'no comment': _xml(_oneAya, head: ''),
      'two comments': _xml('$_oneAya<!--m-->'),
      '"--" in a comment': _xml(_oneAya, head: '<!-- a -- b -->'),
      'an unterminated comment': _xml('<!-- n', head: ''),
      'content after the root': _xml('$_oneAya x'),
      'a second root': _xml('$_oneAya$_oneAya'),
      'a missing end tag': _xml(_oneAya.replaceFirst('</quran>', '')),
    };

    for (final MapEntry(key: name, value: bytes) in refusals.entries) {
      test(name, () {
        expect(
          () => readTanzilXml(bytes),
          throwsA(
            isA<FormatException>()
                .having((e) => e.message, 'message', startsWith('Tanzil XML'))
                .having((e) => e.source, 'source', isNull),
          ),
        );
      });
    }

    test('naming positions and addresses, never values', () {
      final values = syntheticFixtureSuras();
      final good = tanzilFixtureXml(values);
      final third = values[0].ayat[2];
      final bad = _replace(good, third, [...utf8.encode(third), 0xFF]);
      final message = _messageOf(() => readTanzilXml(bad));
      expect(message, contains('at byte'));
      expect(message, isNot(contains(third.substring(0, 3))));
      expect(message.codeUnits.every((unit) => unit < 0x80), isTrue);

      final gap = utf8.encode(
        utf8.decode(good).replaceFirst('index="2" text', 'index="5" text'),
      );
      expect(
        _messageOf(() => readTanzilXml(gap)),
        contains('sura 1 aya 2 has an index other than 2'),
      );
    });

    test('a character XML does not allow, by U+XXXX', () {
      expect(
        _messageOf(
          () => readTanzilXml(_replace(_xml(_oneAya), 'T', [0xEF, 0xBF, 0xBE])),
        ),
        contains('U+FFFE'),
      );
    });
  });
}

String _messageOf(void Function() read) {
  try {
    read();
  } on FormatException catch (e) {
    return e.message;
  }
  fail('no FormatException');
}

/// [bytes] with the first `"<what>"` value replaced by [replacement] bytes.
Uint8List _replace(Uint8List bytes, String what, List<int> replacement) {
  final needle = utf8.encode('"$what"');
  for (var i = 0; i + needle.length <= bytes.length; i++) {
    var match = true;
    for (var j = 0; match && j < needle.length; j++) {
      match = bytes[i + j] == needle[j];
    }
    if (match) {
      return Uint8List.fromList([
        ...bytes.sublist(0, i + 1),
        ...replacement,
        ...bytes.sublist(i + needle.length - 1),
      ]);
    }
  }
  throw ArgumentError.value(what, 'what', 'not found');
}
