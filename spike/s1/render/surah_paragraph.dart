import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/word_span.dart';

/// Where a line starts, in pack terms: [ayah] is the ayah number and
/// [offset] a UTF-16 offset into its text. The text's length means the
/// line starts with the ayah's marker, -1 with the page mark before it.
typedef LineStart = ({int ayah, int offset});

/// What one block shows: consecutive ayat of one surah as whole pack values
/// placed side by side, each followed by its marker. The first ayah may
/// start at a stored word offset ([startOffset]) or at its marker (the
/// text's length), which is how a block continues a line flow begun in the
/// block before it. A page mark ([pageMarks]) sits before the ayah it
/// names, inside the line.
///
/// Spike code reads [PackText.verbatim] here; in M1.2 this becomes a
/// listed `PackText` sink.
final class SurahBlockContent {
  SurahBlockContent({
    required this.firstAyah,
    required List<PackText> ayat,
    required List<List<WordSpan>> words,
    this.basmala,
    this.startOffset = 0,
    Set<QuranAddress> pageMarks = const {},
    Map<QuranAddress, Color> wordColours = const {},
  }) : ayat = List.unmodifiable(ayat),
       words = List.unmodifiable(words),
       pageMarks = Set.unmodifiable(pageMarks),
       wordColours = Map.unmodifiable(wordColours) {
    if (firstAyah.isWord) {
      throw ArgumentError.value(firstAyah, 'firstAyah', 'is a word address');
    }
    if (ayat.isEmpty || ayat.length != words.length) {
      throw ArgumentError('one word list per ayah, and at least one ayah');
    }
    final length = ayat.first.verbatim.length;
    if (startOffset != 0 &&
        startOffset != length &&
        !words.first.any((word) => word.start == startOffset)) {
      throw ArgumentError.value(
        startOffset,
        'startOffset',
        'is not a stored word start of ${firstAyah.ayahAddress}',
      );
    }
    for (final ayah in pageMarks) {
      final index = indexOf(ayah);
      if (index == null || ayah.isWord || (index == 0 && startOffset != 0)) {
        throw ArgumentError.value(ayah, 'pageMarks', 'starts no ayah here');
      }
    }
  }

  final QuranAddress firstAyah;
  final List<PackText> ayat;
  final List<List<WordSpan>> words;
  final PackText? basmala;
  final int startOffset;
  final Set<QuranAddress> pageMarks;

  /// Words drawn in another colour than `quran-ink` (tajweed, `WQ-01`). An
  /// ayah with one is sliced at every stored word offset.
  final Map<QuranAddress, Color> wordColours;

  int get length => ayat.length;

  QuranAddress ayahAt(int index) =>
      QuranAddress(firstAyah.riwaya, firstAyah.surah, firstAyah.ayah + index);

  /// The index in this block of the ayah of [address], or null.
  int? indexOf(QuranAddress address) {
    if (address.riwaya != firstAyah.riwaya ||
        address.surah != firstAyah.surah) {
      return null;
    }
    final index = address.ayah - firstAyah.ayah;
    return index >= 0 && index < ayat.length ? index : null;
  }

  /// The ayah indices preceded by a page mark, in reading order.
  List<int> get pageMarkIndices => [
    for (var i = 0; i < ayat.length; i++)
      if (pageMarks.contains(ayahAt(i))) i,
  ];

  /// The offset the ayah at [index] starts from in this block.
  int baseOf(int index) => index == 0 ? startOffset : 0;

  bool sameAs(SurahBlockContent other) =>
      identical(this, other) ||
      (other.firstAyah == firstAyah &&
          other.basmala == basmala &&
          other.startOffset == startOffset &&
          listEquals(other.ayat, ayat) &&
          _sameWords(other.words, words) &&
          setEquals(other.pageMarks, pageMarks) &&
          mapEquals(other.wordColours, wordColours));

  static bool _sameWords(List<List<WordSpan>> a, List<List<WordSpan>> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!listEquals(a[i], b[i])) return false;
    }
    return true;
  }
}

/// The spans of [text] from [from] on, cut only at stored word offsets and
/// at [hideFrom]. With neither [colours] nor [hideFrom] the text is one
/// span. With [colours] it is cut at every stored word offset, each word and
/// each stretch between words its own span, and words numbered in [colours]
/// take that colour. From [hideFrom], a stored word start, the text is drawn
/// in [hidden]. The slices joined in order are the text from [from].
List<InlineSpan> ayahTextSpans(
  PackText text,
  List<WordSpan> words, {
  int from = 0,
  Map<int, Color> colours = const {},
  int? hideFrom,
  Color? hidden,
}) {
  final value = text.verbatim;
  if (from == value.length) return const [];
  if (colours.isEmpty && hideFrom == null) {
    return [TextSpan(text: from == 0 ? value : value.substring(from))];
  }
  final cuts = <int>{
    from,
    value.length,
    if (colours.isNotEmpty)
      for (final word in words)
        if (word.start >= from) ...[word.start, word.end],
    if (hideFrom != null && hideFrom > from && hideFrom < value.length)
      hideFrom,
  }.toList()..sort();
  final coloured = {
    for (final word in words)
      if (colours[word.number] case final colour?) word.start: (word, colour),
  };
  return [
    for (var k = 0; k + 1 < cuts.length; k++)
      TextSpan(
        text: value.substring(cuts[k], cuts[k + 1]),
        style: switch ((hideFrom, coloured[cuts[k]])) {
          (final hide?, _) when cuts[k] >= hide => TextStyle(color: hidden),
          (_, (final WordSpan word, final Color colour))
              when word.end == cuts[k + 1] =>
            TextStyle(color: colour),
          _ => null,
        },
      ),
  ];
}

/// The size an `AyahMarker` of [diameter] takes under [scaler]: its
/// diameter follows the text scale (D-057).
Size ayahMarkerSize(TextScaler scaler, double diameter) =>
    Size.square(scaler.scale(diameter));

/// How a block hides its lines after [SurahParagraph.maxLines] and moves its
/// centred last line.
enum BandCut {
  /// The text from the cut on is drawn transparent, and a centred last line
  /// is drawn again from a paragraph of its own: no glyph is cut, at the
  /// cost of laying the block out twice.
  recolour,

  /// The paragraph is clipped at the band edge and the last band drawn
  /// again moved: one layout, but a glyph whose ink crosses the edge is cut
  /// or half moved (`bandEdgeInk` measures how often).
  clip,
}

/// The one size of every placeholder of a block: a marker with a gap on
/// each side, as tall as the tallest mark. Markers are all one size; a page
/// mark must fit in a marker's place (see `SurahParagraph._slotOf`).
Size _slotSize(List<Size> markers, List<Size> pageMarks, double gap) {
  final marker = markers.first;
  if (markers.any((size) => size != marker)) {
    throw ArgumentError('markers differ in size');
  }
  final width = gap + marker.width + gap;
  if (pageMarks.any((size) => size.width > width)) {
    throw ArgumentError('a page mark is wider than a marker with its gaps');
  }
  return Size(
    width,
    [marker.height, for (final size in pageMarks) size.height].reduce(math.max),
  );
}

enum _Kind { pageMark, text, marker }

/// One placeholder: an ayah's marker or the page mark before an ayah.
final class _Mark {
  const _Mark(this.segment, this.size, {this.marker, this.pageMark});

  final _Segment segment;
  final Size size;
  final int? marker;
  final int? pageMark;
}

final class _Segment {
  const _Segment(this.kind, this.ayah, this.start, this.end);

  final _Kind kind;
  final int ayah;
  final int start;
  final int end;
}

/// The text of a [SurahBlockContent] laid out as one paragraph: justified,
/// right to left, Arabic, with each marker and page mark an inline
/// placeholder. Coordinates are the block's: the basmala, when given, is a
/// centred paragraph of its own above the ayat (RD-02).
///
/// The space the board writes on each side of a marker (`Screens.dc.html`,
/// the surah-mode text) is not a character here: the marker's placeholder is
/// widened by the advance of U+0020 in the same style on each side, so the
/// paragraph holds the pack values and one U+FFFC per mark and nothing else.
/// Every placeholder takes that one width (see `_slotOf`). Unlike the
/// board's spaces these gaps do not stretch with justification, and a
/// marker that ends or starts a line keeps its gap at the margin.
final class SurahParagraph {
  SurahParagraph(
    this.content, {
    required TextStyle style,
    required TextScaler textScaler,
    required List<Size> markerSizes,
    List<Size> pageMarkSizes = const [],
    this.centreLastLine = false,
    this.maxLines,
    this.cut = BandCut.recolour,
  }) : _style = style,
       _textScaler = textScaler,
       _hidden = (style.color ?? (throw ArgumentError('style has no colour')))
           .withValues(alpha: 0) {
    final marks = content.pageMarkIndices;
    if (markerSizes.length != content.length ||
        pageMarkSizes.length != marks.length) {
      throw ArgumentError('one size per marker and per page mark');
    }
    _gap = _spaceAdvance(style, textScaler);
    final xHeight = textScaler.scale(style.fontSize!) * _quranXHeight;
    PlaceholderDimensions placeholder(double width, double height) =>
        PlaceholderDimensions(
          size: Size(width, height),
          alignment: ui.PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          baselineOffset: height / 2 + xHeight / 2,
        );

    final slot = _slotSize(markerSizes, pageMarkSizes, _gap);
    final dimensions = placeholder(slot.width, slot.height);
    void addPlaceholder(_Mark mark) {
      _dimensions.add(dimensions);
      if (mark.marker case final i?) _markerAt[i] = _placeholders.length;
      if (mark.pageMark case final i?) _pageMarkAt[i] = _placeholders.length;
      _placeholders.add(mark);
      _segments.add(mark.segment);
    }

    var at = 0;
    var mark = 0;
    for (var i = 0; i < content.length; i++) {
      if (mark < marks.length && marks[mark] == i) {
        addPlaceholder(
          _Mark(
            _Segment(_Kind.pageMark, i, at, ++at),
            pageMarkSizes[mark++],
            pageMark: i,
          ),
        );
      }
      final length = content.ayat[i].verbatim.length - content.baseOf(i);
      if (length > 0) {
        _textOf[i] = _Segment(_Kind.text, i, at, at + length);
        _segments.add(_textOf[i]!);
        at += length;
      }
      addPlaceholder(
        _Mark(_Segment(_Kind.marker, i, at, ++at), markerSizes[i], marker: i),
      );
    }
    _length = at;
  }

  final SurahBlockContent content;
  final bool centreLastLine;

  /// Lines after this many are laid out but neither painted nor hit; a
  /// block that continues in the next one ends on a full, justified line.
  final int? maxLines;
  final BandCut cut;

  final TextStyle _style;
  final TextScaler _textScaler;
  final Color _hidden;
  late final double _gap;
  // ui.Paragraph rather than TextPainter: only it answers getLineNumberAt,
  // which finds a line's start in log time; TextPainter.getLineBoundary
  // costs a pass over every line.
  ui.Paragraph? _body;
  ui.Paragraph? _basmala;
  ui.Paragraph? _lastLine;
  late final int _length;
  final _dimensions = <PlaceholderDimensions>[];
  final _segments = <_Segment>[];
  final _placeholders = <_Mark>[];
  final _textOf = <int, _Segment>{};
  final _markerAt = <int, int>{};
  final _pageMarkAt = <int, int>{};

  double _width = 0;
  double _bodyTop = 0;
  double _shift = 0;
  double _lastLineDx = 0;
  int? _cutLine;
  bool _recoloured = false;
  List<ui.LineMetrics> _metrics = const [];
  final _tops = <double>[];
  final _bottoms = <double>[];
  List<int> _lineStarts = const [];
  int _visible = 0;
  List<Rect>? _slots;

  /// The paragraph's spans from offset [from], a segment start or a stored
  /// word start, with the text from [hideFrom] on drawn transparent.
  TextSpan _spansFrom(int from, {int? hideFrom}) => TextSpan(
    style: _style,
    locale: _arabic,
    children: [
      for (final segment in _segments)
        if (segment.end > from)
          if (segment.kind == _Kind.text)
            ...ayahTextSpans(
              content.ayat[segment.ayah],
              content.words[segment.ayah],
              from: _local(segment, math.max(from, segment.start)),
              colours: _coloursOf(segment.ayah),
              hideFrom: hideFrom == null || hideFrom >= segment.end
                  ? null
                  : _local(segment, math.max(hideFrom, segment.start)),
              hidden: _hidden,
            )
          else
            _placeholderSpan,
    ],
  );

  int _local(_Segment text, int offset) =>
      content.baseOf(text.ayah) + offset - text.start;

  List<PlaceholderDimensions> _dimensionsFrom(int from) => [
    for (final (k, mark) in _placeholders.indexed)
      if (mark.segment.start >= from) _dimensions[k],
  ];

  Map<int, Color> _coloursOf(int index) {
    if (content.wordColours.isEmpty) return const {};
    final ayah = content.ayahAt(index);
    return {
      for (final MapEntry(key: address, value: colour)
          in content.wordColours.entries)
        if (address.ayahAddress == ayah && address.word != null)
          address.word!: colour,
    };
  }

  void layout(double width) {
    _width = width;
    _disposeParagraphs();
    if (content.basmala case final basmala?) {
      _basmala = _build(
        TextSpan(text: basmala.verbatim, style: _style, locale: _arabic),
        TextAlign.center,
        const [],
      );
    }
    _bodyTop = _basmala?.height ?? 0;
    final body = _body = _build(_spansFrom(0), TextAlign.justify, _dimensions);
    _metrics = body.computeLineMetrics();
    _tops.clear();
    _bottoms.clear();
    for (final (k, line) in _metrics.indexed) {
      _tops.add(k == 0 ? 0 : _bottoms[k - 1]);
      _bottoms.add(line.baseline + line.descent);
    }
    _visible = math.min(_metrics.length, maxLines ?? _metrics.length);
    _lineStarts = _findLineStarts();
    _slots = null;
    _shift = 0;
    _cutLine = null;
    if (_visible < _metrics.length) {
      _cutLine = _visible;
    } else if (centreLastLine && _metrics.isNotEmpty) {
      // The line ends with the last marker's slot, whose trailing gap is
      // not ink: centre what is drawn.
      final last = _metrics.last;
      _shift = (width - last.width - _gap) / 2 - last.left;
      if (_shift != 0) _cutLine = _metrics.length - 1;
    }
    _recoloured = false;
    if (cut == BandCut.recolour && _cutLine != null) _recolour(_cutLine!);
  }

  ui.Paragraph _build(
    InlineSpan span,
    TextAlign align,
    List<PlaceholderDimensions> dimensions,
  ) {
    final builder = ui.ParagraphBuilder(
      _style.getParagraphStyle(
        textAlign: align,
        textDirection: TextDirection.rtl,
        textScaler: _textScaler,
        locale: _arabic,
      ),
    );
    span.build(builder, textScaler: _textScaler, dimensions: dimensions);
    return builder.build()..layout(ui.ParagraphConstraints(width: _width));
  }

  /// Lays the body out again with the text from line [line] on drawn
  /// transparent, and, when centring, that line again from its own centred
  /// paragraph. The cut must fall on a stored word start, a marker or a
  /// page mark; elsewhere the block falls back to [BandCut.clip].
  void _recolour(int line) {
    final from = _lineStarts[line];
    final segment = _segmentAt(from)!;
    if (segment.kind == _Kind.text && from != segment.start) {
      final local = _local(segment, from);
      if (!content.words[segment.ayah].any((w) => w.start == local)) return;
    }
    _body!.dispose();
    _body = _build(
      _spansFrom(0, hideFrom: from),
      TextAlign.justify,
      _dimensions,
    );
    if (!listEquals(_findLineStarts(), _lineStarts)) {
      throw StateError('recolouring changed the line breaks');
    }
    _recoloured = true;
    if (_shift == 0) return;
    final last = _lastLine = _build(
      _spansFrom(from),
      TextAlign.center,
      _dimensionsFrom(from),
    );
    final metrics = last.computeLineMetrics();
    if (metrics.length != 1) {
      throw StateError('the last line broke in two on its own');
    }
    _lastLineDx = _metrics.last.left + _shift - metrics.single.left;
  }

  /// The first offset of each line: for line k, the least offset after the
  /// start of line k - 1 that lies on line k or later.
  List<int> _findLineStarts() {
    final body = _body!;
    final starts = <int>[if (_metrics.isNotEmpty) 0];
    for (var k = 1; k < _metrics.length; k++) {
      var low = starts.last + 1;
      var high = _length;
      while (low < high) {
        final middle = (low + high) ~/ 2;
        if ((body.getLineNumberAt(middle) ?? _metrics.length) >= k) {
          high = middle;
        } else {
          low = middle + 1;
        }
      }
      starts.add(low);
    }
    assert(_length > _checkedLength || listEquals(starts, _walkLineStarts()));
    return starts;
  }

  /// The line starts by walking line boundaries, which costs a pass over all
  /// lines per line; a debug check of [_findLineStarts] on small blocks.
  List<int> _walkLineStarts() {
    final starts = <int>[];
    var position = 0;
    while (position < _length) {
      final line = _body!.getLineBoundary(TextPosition(offset: position));
      if (starts.isEmpty || line.start > starts.last) starts.add(line.start);
      position = line.end > position ? line.end : position + 1;
    }
    return starts;
  }

  double get width => _width;

  /// The block's height: the basmala and the visible lines.
  double get height => _bodyTop + (_visible == 0 ? 0 : _bottoms[_visible - 1]);

  /// Where the ayat begin, below the basmala.
  double get bodyTop => _bodyTop;

  int get lineCount => _metrics.length;

  int get visibleLineCount => _visible;

  /// How far the last line was moved to centre it; 0 when it was not.
  double get lastLineShift => _shift;

  /// The advance of U+0020 in this style, the gap on each side of a marker.
  double get markerGap => _gap;

  /// The visible lines' bands in block coordinates. They tile the body:
  /// each runs from the bottom of the one above to its own descent.
  List<Rect> get lineBands => [
    for (var k = 0; k < _visible; k++)
      Rect.fromLTRB(0, _bodyTop + _tops[k], _width, _bodyTop + _bottoms[k]),
  ];

  /// The widths of the visible lines as laid out, and as they would be
  /// unjustified, which is the stretch justification adds to each.
  List<({double laidOut, double natural})> lineWidths() {
    final twin = _build(_spansFrom(0), TextAlign.start, _dimensions);
    final natural = twin.computeLineMetrics();
    twin.dispose();
    if (natural.length != _metrics.length) {
      throw StateError('alignment changed the line count');
    }
    return [
      for (var k = 0; k < _visible; k++)
        (laidOut: _metrics[k].width, natural: natural[k].width),
    ];
  }

  /// Paragraph offsets of the visible lines' first characters.
  List<int> get lineStarts => _lineStarts.sublist(0, _visible);

  List<LineStart> get lineStartPositions => [
    for (final start in lineStarts) _positionOf(start),
  ];

  LineStart _positionOf(int offset) {
    final segment = _segmentAt(offset)!;
    final ayah = content.ayahAt(segment.ayah).ayah;
    return switch (segment.kind) {
      _Kind.pageMark => (ayah: ayah, offset: -1),
      _Kind.marker => (
        ayah: ayah,
        offset: content.ayat[segment.ayah].verbatim.length,
      ),
      _Kind.text => (
        ayah: ayah,
        offset: content.baseOf(segment.ayah) + offset - segment.start,
      ),
    };
  }

  /// The line on which the ayah at [index] begins, counting hidden lines:
  /// the line of its page mark if it has one, else of its first character.
  int lineOfAyah(int index) => _lineOfOffset(
    switch (_pageMarkAt[index]) {
      final at? => _placeholders[at].segment,
      null => _textOf[index] ?? _placeholders[_markerAt[index]!].segment,
    }.start,
  );

  /// The word or ayah marker at [point], in block coordinates; null over a
  /// space, a page mark, the basmala or a hidden line.
  QuranAddress? hit(Offset point) {
    final y = point.dy - _bodyTop;
    if (_visible == 0 || y < 0 || y >= _bottoms[_visible - 1]) return null;
    if (point.dx < 0 || point.dx > _width) return null;
    final line = _lineAtY(y);
    final probe = Offset(point.dx - _shiftOf(line), y);
    final position = _body!.getPositionForOffset(probe).offset;
    for (final offset in {position, position - 1}) {
      final segment = _segmentAt(offset);
      if (segment == null) continue;
      switch (segment.kind) {
        case _Kind.pageMark:
          continue;
        case _Kind.marker:
          if (markerRect(segment.ayah).contains(point)) {
            return content.ayahAt(segment.ayah);
          }
        case _Kind.text:
          if (_wordAt(segment, offset, probe, line) case final word?) {
            return word;
          }
      }
    }
    return null;
  }

  QuranAddress? _wordAt(_Segment segment, int offset, Offset probe, int line) {
    final words = content.words[segment.ayah];
    final local = content.baseOf(segment.ayah) + offset - segment.start;
    var low = 0;
    var high = words.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (words[middle].start <= local) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    for (final index in [low - 1, low]) {
      if (index < 0 || index >= words.length) continue;
      final word = words[index];
      final range = _wordRange(segment.ayah, word);
      if (range == null) continue;
      for (final box in _rawBoxes(range.$1, range.$2)) {
        if (_lineOfBox(box) == line &&
            box.left <= probe.dx &&
            probe.dx <= box.right) {
          final ayah = content.ayahAt(segment.ayah);
          return QuranAddress(ayah.riwaya, ayah.surah, ayah.ayah, word.number);
        }
      }
    }
    return null;
  }

  /// One rect per visible line for a word, or for an ayah's text with its
  /// marker; empty when it is not drawn in this block.
  List<Rect> boxesOf(QuranAddress address) {
    final index = content.indexOf(address);
    if (index == null) return const [];
    final word = address.word;
    if (word != null) {
      final span = content.words[index].where((w) => w.number == word);
      if (span.isEmpty) return const [];
      final range = _wordRange(index, span.single);
      return range == null ? const [] : _merged(_rawBoxes(range.$1, range.$2));
    }
    final text = _textOf[index];
    return _merged([
      if (text != null) ..._rawBoxes(text.start, text.end),
      _asTextBox(_markerRaw(index)),
    ]);
  }

  /// The top of the line on which the ayah of [ayah] starts in this block,
  /// or null when it starts before the block or on a hidden line.
  double? topOf(QuranAddress ayah) {
    final index = content.indexOf(ayah);
    if (index == null || (index == 0 && content.startOffset != 0)) return null;
    final first = _textOf[index] ?? _placeholders[_markerAt[index]!].segment;
    final line = _lineOfOffset(first.start);
    return line < _visible ? _bodyTop + _tops[line] : null;
  }

  /// Where the marker of the ayah at [index] is drawn, in block coordinates.
  Rect markerRect(int index) => _placed(_markerRaw(index));

  /// Where the page mark before the ayah at [index] is drawn.
  Rect pageMarkRect(int index) => _placed(_childRect(_pageMarkAt[index]!));

  /// Whether [rect], in block coordinates, lies on a visible line.
  bool isVisible(Rect rect) =>
      _visible == _metrics.length ||
      rect.center.dy - _bodyTop < _bottoms[_visible - 1];

  void paint(Canvas canvas, Offset offset) {
    if (_basmala case final basmala?) canvas.drawParagraph(basmala, offset);
    final body = _body!;
    final origin = offset.translate(0, _bodyTop);
    final line = _cutLine;
    if (line == null || _recoloured) {
      canvas.drawParagraph(body, origin);
      if (_lastLine case final last?) {
        canvas.drawParagraph(last, origin.translate(_lastLineDx, _tops[line!]));
      }
      return;
    }
    final edge = _tops[line];
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(-_far, -_far, _far, edge).shift(origin));
    canvas
      ..drawParagraph(body, origin)
      ..restore();
    if (_shift != 0) {
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(-_far, edge, _far, _far).shift(origin));
      canvas
        ..drawParagraph(body, origin.translate(_shift, 0))
        ..restore();
    }
  }

  /// Whether lines were hidden or moved by recolouring rather than clipping.
  bool get recoloured => _recoloured;

  /// Paints the ayat as laid out, with no centring or clip: what the
  /// band-edge ink check scans. Body coordinates.
  void paintUnclipped(Canvas canvas, Offset offset) =>
      canvas.drawParagraph(_body!, offset);

  void dispose() => _disposeParagraphs();

  void _disposeParagraphs() {
    _body?.dispose();
    _basmala?.dispose();
    _lastLine?.dispose();
    _body = _basmala = _lastLine = null;
  }

  (int, int)? _wordRange(int index, WordSpan word) {
    final base = content.baseOf(index);
    if (word.start < base) return null;
    final segment = _textOf[index]!;
    return (segment.start + word.start - base, segment.start + word.end - base);
  }

  List<TextBox> _rawBoxes(int start, int end) => _body!.getBoxesForRange(
    start,
    end,
    boxHeightStyle: ui.BoxHeightStyle.max,
  );

  /// The slot placeholder [k] is drawn in. SkParagraph (Flutter 3.44)
  /// lays the placeholders of a right-to-left line out in the reverse of
  /// their order among themselves, each in the slot of another; the text
  /// between them keeps its place. With every slot of one size the layout
  /// is the right one and only which slot is whose is wrong, so the line's
  /// placeholders, in order, take its slots from the right.
  Rect _slotOf(int k) {
    final slots = _slots ??= _assignSlots();
    return slots[k];
  }

  List<Rect> _assignSlots() {
    final boxes = [
      for (final mark in _placeholders)
        _body!
            .getBoxesForRange(mark.segment.start, mark.segment.end)
            .single
            .toRect(),
    ];
    final byLine = <int, List<int>>{};
    for (final (k, box) in boxes.indexed) {
      byLine.putIfAbsent(_lineAtY(box.center.dy), () => []).add(k);
    }
    final slots = List<Rect>.filled(boxes.length, Rect.zero);
    for (final line in byLine.values) {
      final places = [for (final k in line) boxes[k]]
        ..sort((a, b) => b.left.compareTo(a.left));
      for (final (j, k) in line.indexed) {
        slots[k] = places[j];
      }
    }
    return slots;
  }

  /// Where placeholder [k]'s mark is drawn in body coordinates: centred in
  /// its slot, which holds a gap for the board's space on each side.
  Rect _childRect(int k) => Rect.fromCenter(
    center: _slotOf(k).center,
    width: _placeholders[k].size.width,
    height: _placeholders[k].size.height,
  );

  Rect _markerRaw(int index) => _childRect(_markerAt[index]!);

  static TextBox _asTextBox(Rect rect) => TextBox.fromLTRBD(
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
    TextDirection.rtl,
  );

  /// Body rects merged to one per line, visible lines only, moved to block
  /// coordinates and, on a centred last line, by its shift. A range's box
  /// holds the space that ends a justified line, which hangs past its left
  /// edge; it is cut at the block's edges.
  List<Rect> _merged(Iterable<TextBox> boxes) {
    final byLine = <int, Rect>{};
    for (final box in boxes) {
      final line = _lineOfBox(box);
      if (line >= _visible) continue;
      final rect = Rect.fromLTRB(
        math.max(box.left, 0),
        box.top,
        math.min(box.right, _width),
        box.bottom,
      );
      byLine.update(line, (r) => r.expandToInclude(rect), ifAbsent: () => rect);
    }
    return [
      for (final line in byLine.keys.toList()..sort())
        byLine[line]!.shift(Offset(_shiftOf(line), _bodyTop)),
    ];
  }

  Rect _placed(Rect raw) =>
      raw.shift(Offset(_shiftOf(_lineAtY(raw.center.dy)), _bodyTop));

  double _shiftOf(int line) => line == _metrics.length - 1 ? _shift : 0;

  int _lineOfBox(TextBox box) => _lineAtY((box.top + box.bottom) / 2);

  int _lineAtY(double y) {
    var low = 0;
    var high = _bottoms.length - 1;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (_bottoms[middle] <= y) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  int _lineOfOffset(int offset) {
    var low = 0;
    var high = _lineStarts.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (_lineStarts[middle] <= offset) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }

  _Segment? _segmentAt(int offset) {
    if (offset < 0 || offset >= _length) return null;
    var low = 0;
    var high = _segments.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (_segments[middle].start <= offset) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return _segments[low];
  }

  static double _spaceAdvance(TextStyle style, TextScaler scaler) {
    final space = TextPainter(
      text: TextSpan(text: _space, style: style),
      textDirection: TextDirection.rtl,
      locale: _arabic,
      textScaler: scaler,
    )..layout();
    final width = space.width;
    space.dispose();
    return width;
  }
}

const Locale _arabic = Locale('ar');

const String _space = ' ';

const WidgetSpan _placeholderSpan = WidgetSpan(
  alignment: ui.PlaceholderAlignment.baseline,
  baseline: TextBaseline.alphabetic,
  child: SizedBox.shrink(),
);

// .qk-ayah-no `vertical-align: middle` centres the marker half the parent's
// x-height above the baseline. AmiriQuran-Regular.ttf, OS/2 sxHeight 433 of
// unitsPerEm 1000. Flutter's PlaceholderAlignment.middle centres it in the
// line box instead, about 9 px higher at 25 px.
const double _quranXHeight = 0.433;

// Blocks up to this many code units check _findLineStarts in debug runs.
const int _checkedLength = 20000;

// A clip edge no text reaches, so that a clip cuts in one direction only.
const double _far = 1e7;
