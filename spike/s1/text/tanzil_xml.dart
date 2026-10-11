import 'dart:convert';
import 'dart:typed_data';

/// One `<aya>` of a Tanzil XML file. The UTF-8 bytes of [text] are the
/// [byteLength] bytes of the file from [byteOffset], up to the closing
/// quote; likewise for [basmala], the `bismillah` attribute, which only an
/// ayah numbered 1 may carry.
typedef TanzilAyah = ({
  int surah,
  int ayah,
  String text,
  int byteOffset,
  int byteLength,
  String? basmala,
  int? basmalaByteOffset,
  int? basmalaByteLength,
});

typedef TanzilSura = ({
  int index,
  String name,
  int nameByteOffset,
  int nameByteLength,
});

/// A whole file: its suras, its ayat in file order, and the one comment
/// outside the root element (the copyright block), as written between `<!--`
/// and `-->`.
typedef TanzilXml = ({
  List<TanzilSura> suras,
  List<TanzilAyah> ayat,
  String notice,
  int noticeByteOffset,
});

/// Reads the Tanzil XML form
/// `<quran><sura index name><aya index text [bismillah]/></sura></quran>`
/// with nothing changed: every value is the
/// exact substring between its quotes, and its UTF-8 equals the source bytes
/// at its offset.
///
/// Anything a conforming XML parser would change, or that is not in that
/// closed form, is refused with a [FormatException] naming a byte offset and
/// an address, never a value: a byte order mark, malformed UTF-8, a
/// character XML does not allow, an entity or character reference, CDATA, a
/// processing instruction other than the declaration, a DOCTYPE, an unknown
/// element or attribute, a tab or line break inside a value (XML turns them
/// into spaces), indices that are not 1, 2, 3 and so on, and anything but
/// exactly one comment outside the root element.
TanzilXml readTanzilXml(Uint8List bytes) => _TanzilReader(bytes).read();

/// In the order XML requires them.
const _declarationAttributes = ['version', 'encoding', 'standalone'];
const _suraAttributes = {'index', 'name'};
const _ayaAttributes = {'index', 'text', 'bismillah'};

typedef _Range = ({int start, int end});

final class _TanzilReader {
  _TanzilReader(this._bytes);

  final Uint8List _bytes;
  var _at = 0;
  final _suras = <TanzilSura>[];
  final _ayat = <TanzilAyah>[];
  final _comments = <_Range>[];

  TanzilXml read() {
    if (_hasBom(0)) _fail('a byte order mark', 0);
    try {
      utf8.decode(_bytes);
    } on FormatException catch (e) {
      _fail('malformed UTF-8', e.offset ?? 0);
    }
    if (_startsWith('<?xml')) _declaration();
    _misc();
    _quran();
    _misc();
    if (_at != _bytes.length) _fail('content after the root element', _at);
    if (_comments.length != 1) {
      throw FormatException(
        'Tanzil XML: ${_comments.length} comments outside the root element, '
        'not exactly one',
      );
    }
    final notice = _comments.single;
    return (
      suras: List.unmodifiable(_suras),
      ayat: List.unmodifiable(_ayat),
      notice: _value(notice, 'the comment'),
      noticeByteOffset: notice.start,
    );
  }

  Never _fail(String what, int at) =>
      throw FormatException('Tanzil XML: $what at byte $at');

  bool _startsWith(String ascii, [int? at]) {
    final from = at ?? _at;
    if (from + ascii.length > _bytes.length) return false;
    for (var i = 0; i < ascii.length; i++) {
      if (_bytes[from + i] != ascii.codeUnitAt(i)) return false;
    }
    return true;
  }

  bool _hasBom(int at) =>
      at + 3 <= _bytes.length &&
      _bytes[at] == 0xEF &&
      _bytes[at + 1] == 0xBB &&
      _bytes[at + 2] == 0xBF;

  bool _take(String ascii) {
    if (!_startsWith(ascii)) return false;
    _at += ascii.length;
    return true;
  }

  static bool _isSpace(int byte) =>
      byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D;

  bool _skipSpace() {
    final from = _at;
    while (_at < _bytes.length && _isSpace(_bytes[_at])) {
      _at++;
    }
    return _at > from;
  }

  /// `<name` followed by a space, `>` or `/>`, so that `<surah` is not
  /// taken for `<sura`.
  bool _takeTagStart(String name) {
    if (!_startsWith('<$name')) return false;
    final next = _at + name.length + 1;
    if (next < _bytes.length &&
        (_isSpace(_bytes[next]) ||
            _bytes[next] == 0x3E ||
            _bytes[next] == 0x2F)) {
      _at = next;
      return true;
    }
    return false;
  }

  void _declaration() {
    _at += 5;
    if (_at >= _bytes.length || !_isSpace(_bytes[_at])) {
      _fail('a processing instruction', 0);
    }
    final (attributes, _) = _attributes(
      _declarationAttributes.toSet(),
      'the XML declaration',
      declaration: true,
    );
    String? pseudo(String name) => switch (attributes[name]) {
      final range? => _value(range, 'the XML declaration'),
      null => null,
    };
    if ('${attributes.keys}' !=
        '${_declarationAttributes.where(attributes.containsKey)}') {
      _fail('XML declaration attributes out of order', 0);
    }
    if (pseudo('version') != '1.0') {
      _fail('an XML declaration without version 1.0', 0);
    }
    final encoding = pseudo('encoding');
    if (encoding != null && encoding.toLowerCase() != 'utf-8') {
      _fail('an XML declaration naming an encoding other than UTF-8', 0);
    }
    final standalone = pseudo('standalone');
    if (standalone != null && standalone != 'yes' && standalone != 'no') {
      _fail('an XML declaration with an invalid standalone', 0);
    }
  }

  /// White space and comments outside the root element.
  void _misc() {
    while (true) {
      _skipSpace();
      if (_startsWith('<!--')) {
        _comment();
      } else if (_startsWith('<?')) {
        _fail('a processing instruction', _at);
      } else if (_startsWith('<!')) {
        _fail('a DOCTYPE or markup declaration', _at);
      } else {
        return;
      }
    }
  }

  void _comment() {
    final start = _at + 4;
    var end = start;
    while (end + 1 < _bytes.length &&
        !(_bytes[end] == 0x2D && _bytes[end + 1] == 0x2D)) {
      end++;
    }
    if (end + 1 >= _bytes.length) _fail('an unterminated comment', _at);
    if (end + 2 >= _bytes.length || _bytes[end + 2] != 0x3E) {
      _fail('"--" inside a comment', end);
    }
    _comments.add((start: start, end: end));
    _at = end + 3;
  }

  /// Refuses whatever may not stand at this point inside [element].
  Never _unexpectedContent(String element) {
    if (_at >= _bytes.length) _fail('the end of input inside $element', _at);
    if (_startsWith('<!--')) _fail('a comment inside $element', _at);
    if (_startsWith('<![CDATA[')) _fail('a CDATA section', _at);
    if (_startsWith('<!')) _fail('a markup declaration', _at);
    if (_startsWith('<?')) _fail('a processing instruction', _at);
    if (_startsWith('<')) _fail('an unknown element inside $element', _at);
    _fail('character data or a reference inside $element', _at);
  }

  void _endTag(String name) {
    _skipSpace();
    if (!_take('>')) _fail('a malformed end tag of $name', _at);
  }

  void _quran() {
    if (!_takeTagStart('quran')) _fail('no <quran> root element', _at);
    final (_, empty) = _attributes(const {}, 'quran');
    if (empty) _fail('a quran element without suras', _at);
    while (true) {
      _skipSpace();
      if (_take('</quran')) {
        _endTag('quran');
        break;
      }
      if (!_takeTagStart('sura')) _unexpectedContent('quran');
      _sura();
    }
    if (_suras.isEmpty) _fail('a quran element without suras', _at);
  }

  void _sura() {
    final index = _suras.length + 1;
    final where = 'sura $index';
    final (attributes, empty) = _attributes(_suraAttributes, where);
    _index(attributes, index, where);
    final name = _required(attributes, 'name', where);
    _suras.add((
      index: index,
      name: _value(name, '$where name'),
      nameByteOffset: name.start,
      nameByteLength: name.end - name.start,
    ));
    if (empty) _fail('$where without ayat', _at);
    var ayat = 0;
    while (true) {
      _skipSpace();
      if (_take('</sura')) {
        _endTag('sura');
        break;
      }
      if (!_takeTagStart('aya')) _unexpectedContent(where);
      _aya(index, ++ayat);
    }
    if (ayat == 0) _fail('$where without ayat', _at);
  }

  void _aya(int surah, int ayah) {
    final where = 'sura $surah aya $ayah';
    final (attributes, empty) = _attributes(_ayaAttributes, where);
    _index(attributes, ayah, where);
    final text = _required(attributes, 'text', where);
    final basmala = attributes['bismillah'];
    if (basmala != null && ayah != 1) {
      _fail('a bismillah attribute on $where', basmala.start);
    }
    _ayat.add((
      surah: surah,
      ayah: ayah,
      text: _value(text, '$where text'),
      byteOffset: text.start,
      byteLength: text.end - text.start,
      basmala: basmala == null ? null : _value(basmala, '$where bismillah'),
      basmalaByteOffset: basmala?.start,
      basmalaByteLength: basmala == null ? null : basmala.end - basmala.start,
    ));
    if (!empty) {
      if (!_take('</aya')) _fail('content inside $where', _at);
      _endTag('aya');
    }
  }

  _Range _required(Map<String, _Range> attributes, String name, String where) =>
      attributes[name] ?? _fail('$where without a $name attribute', _at);

  void _index(Map<String, _Range> attributes, int expected, String where) {
    final range = _required(attributes, 'index', where);
    if (!_startsWith('$expected', range.start) ||
        range.end - range.start != '$expected'.length) {
      _fail('$where has an index other than $expected', range.start);
    }
  }

  /// The attributes of a tag, up to `>` (false), `/>` (true), or `?>` for the
  /// declaration. Names are lowercase ASCII letters; values are byte ranges.
  (Map<String, _Range>, bool) _attributes(
    Set<String> allowed,
    String where, {
    bool declaration = false,
  }) {
    final found = <String, _Range>{};
    while (true) {
      final spaced = _skipSpace();
      if (declaration) {
        if (_take('?>')) return (found, true);
      } else {
        if (_take('/>')) return (found, true);
        if (_take('>')) return (found, false);
      }
      final nameStart = _at;
      while (_at < _bytes.length &&
          _bytes[_at] >= 0x61 &&
          _bytes[_at] <= 0x7A) {
        _at++;
      }
      if (_at == nameStart || !spaced) {
        _fail('an unexpected byte in the tag of $where', nameStart);
      }
      final name = String.fromCharCodes(_bytes, nameStart, _at);
      if (!allowed.contains(name)) {
        _fail('the unknown attribute "$name" in $where', nameStart);
      }
      if (found.containsKey(name)) {
        _fail('a repeated attribute "$name" in $where', nameStart);
      }
      _skipSpace();
      if (!_take('=')) _fail('an attribute without "=" in $where', _at);
      _skipSpace();
      found[name] = _quoted(where);
    }
  }

  _Range _quoted(String where) {
    if (_at >= _bytes.length || (_bytes[_at] != 0x22 && _bytes[_at] != 0x27)) {
      _fail('an unquoted attribute value in $where', _at);
    }
    final quote = _bytes[_at];
    final start = _at + 1;
    for (var i = start; i < _bytes.length; i++) {
      final byte = _bytes[i];
      if (byte == quote) {
        _at = i + 1;
        return (start: start, end: i);
      }
      if (byte == 0x26) _fail('a reference in an attribute of $where', i);
      if (byte == 0x3C) _fail('"<" in an attribute of $where', i);
      if (byte == 0x09 || byte == 0x0A || byte == 0x0D) {
        _fail('a tab or line break in an attribute of $where', i);
      }
      if (byte < 0x20) _fail('a control character in $where', i);
    }
    _fail('an unterminated attribute value in $where', start);
  }

  /// The value at [range], decoded strictly and checked to re-encode to the
  /// same bytes.
  String _value(_Range range, String where) {
    final source = Uint8List.sublistView(_bytes, range.start, range.end);
    if (source.isEmpty) _fail('an empty value in $where', range.start);
    if (_hasBom(range.start)) {
      _fail('a value beginning with U+FEFF in $where', range.start);
    }
    final String value;
    try {
      // Spelled out so that a reader sees that malformed bytes are refused.
      // ignore: avoid_redundant_argument_values
      value = utf8.decode(source, allowMalformed: false);
    } on FormatException catch (e) {
      _fail('malformed UTF-8 in $where', range.start + (e.offset ?? 0));
    }
    var offset = range.start;
    for (final rune in value.runes) {
      if (!_isXmlChar(rune)) {
        _fail('the character ${_codePoint(rune)} in $where', offset);
      }
      offset += rune < 0x80
          ? 1
          : rune < 0x800
          ? 2
          : rune < 0x10000
          ? 3
          : 4;
    }
    final encoded = utf8.encode(value);
    var same = encoded.length == source.length;
    for (var i = 0; same && i < source.length; i++) {
      same = encoded[i] == source[i];
    }
    if (!same) {
      _fail(
        'a value that does not re-encode to its bytes in $where',
        range.start,
      );
    }
    return value;
  }

  static bool _isXmlChar(int rune) =>
      rune == 0x09 ||
      rune == 0x0A ||
      rune == 0x0D ||
      (rune >= 0x20 && rune <= 0xD7FF) ||
      (rune >= 0xE000 && rune <= 0xFFFD) ||
      (rune >= 0x10000 && rune <= 0x10FFFF);
}

String _codePoint(int rune) =>
    'U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}';
