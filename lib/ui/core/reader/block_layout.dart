import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'package:holyquran/ui/core/metrics/reader_screen_metrics.dart';

import 'planned_ayah.dart';
import 'reader_paragraph.dart';
import 'surah_layout.dart';
import 'surah_text.dart';

/// One block of a [SurahLayout] laid out: a paragraph per segment, stacked
/// line under line, in block coordinates (x from 0 to the plan's width, y
/// from the top of the block, the row of margin marks above its first line
/// included). A row of margin marks inside a paragraph moves the lines below
/// it down (D-181): they are drawn from a copy of the paragraph inked on
/// them alone, so its lines break and are set exactly as without the row.
///
/// It answers where every line, word, mark, marker and page mark is drawn,
/// for targets and highlights (P1-22). Ink may leave a line's band, above or
/// below (S1 finding 2), so nothing here is clipped: a line is hidden by
/// drawing it in transparent ink, never by a clip.
final class BlockLayout {
  BlockLayout(this.plan, this.index, {required this.ink})
    : block = plan.blocks[index] {
    final transparent = ink.withValues(alpha: 0);
    final finalLine = plan.lines.length - 1;
    for (var s = block.firstSegment; s < block.endSegment; s++) {
      final segment = plan.segments[s];
      final ayat = plan.plannedAyat(segment);
      final lastLocal = segment.lineCount - 1;
      final centres = segment.endLine - 1 == finalLine;
      final width = plan.paragraphWidthOf(segment);
      final drops = <double>[0];
      for (var line = segment.firstLine + 1; line < segment.endLine; line++) {
        drops.add(drops.last + plan.rowExtent(line));
      }
      Color inkOn(int line, double drop) =>
          drops[line] == drop && !(centres && line == lastLocal)
          ? ink
          : transparent;
      final body = buildSegment(
        ayat,
        plan.style,
        width,
        colourOfLine: (line) => inkOn(line, 0),
      );
      final copies = [
        for (final drop in drops.toSet().skip(1))
          (
            buildSegment(
              ayat,
              plan.style,
              width,
              colourOfLine: (line) => inkOn(line, drop),
            ),
            drop,
          ),
      ];
      final twin = centres
          ? buildSegment(
              ayat,
              plan.style,
              width,
              colourOfLine: (line) => line == lastLocal ? ink : transparent,
            )
          : null;
      _segments.add(
        _LaidSegment(
          segment,
          ayat,
          body,
          twin,
          copies,
          drops,
          plan.lineTop(segment.firstLine) - plan.blockTop(index),
          plan.style.markGap,
          plan.width,
        ),
      );
    }
    assert(matchesPlan, 'block $index broke its lines unlike its plan');
  }

  final SurahLayout plan;
  final int index;

  /// The colour of the text, `quran-ink`.
  final Color ink;
  final Block block;
  final _segments = <_LaidSegment>[];

  double get width => plan.width;

  double get height => plan.blockHeight(index);

  int get lineCount => block.lineCount;

  /// The band of line [line] of this block: the full width, one line tall.
  /// Bands tile the block but for the rows of margin marks above some lines.
  Rect lineBand(int line) => Rect.fromLTWH(
    0,
    plan.lineTop(block.firstLine + line) - plan.blockTop(index),
    plan.width,
    plan.lineHeight,
  );

  List<Rect> get lineBands => [for (var k = 0; k < lineCount; k++) lineBand(k)];

  /// The ayat whose text is drawn in this block, numbered from 1, in order.
  Iterable<int> get ayat sync* {
    for (final segment in _segments) {
      for (final planned in segment.ayat) {
        if (planned.hasMarker) yield planned.number;
      }
    }
  }

  /// The top of the line on which the text of [ayah] begins, or null when it
  /// is not in this block.
  double? topOfAyah(int ayah) => _parts(ayah).isEmpty
      ? null
      : lineBand(plan.lineOfAyahText(ayah) - block.firstLine).top;

  /// Where word [word] of ayah [ayah] is drawn: one rect, as a word never
  /// breaks across lines; null when it is not in this block.
  Rect? wordBox(int ayah, int word) {
    for (final (laid, planned) in _parts(ayah)) {
      for (final span in planned.ayah.words) {
        if (span.number != word || !laid.holds(planned, span.start)) continue;
        final boxes = laid.boxes(
          laid.offsetOf(planned, span.start),
          laid.offsetOf(planned, span.end),
        );
        return boxes.isEmpty ? null : boxes.single;
      }
    }
    return null;
  }

  /// Where mark [mark] of ayah [ayah] is drawn. A lone mark is shaped onto
  /// the space before it, so when it has no box of its own its box runs
  /// from the token before it.
  List<Rect> markBoxes(int ayah, int mark) {
    for (final (laid, planned) in _parts(ayah)) {
      for (final span in planned.ayah.marks) {
        if (span.number != mark || !laid.holds(planned, span.start)) continue;
        final end = laid.offsetOf(planned, span.end);
        final own = laid.boxes(laid.offsetOf(planned, span.start), end);
        if (own.isNotEmpty) return own;
        final units = planned.units;
        final unit = units.units[units.unitAt(span.start)];
        final before = unit.tokens
            .map((token) => token.$2)
            .where((tokenEnd) => tokenEnd <= span.start)
            .fold(unit.start, math.max);
        return laid.boxes(laid.offsetOf(planned, before), end);
      }
    }
    return const [];
  }

  /// Where the ayah-end marker of [ayah] is drawn, in its slot; null when it
  /// is not in this block.
  Rect? markerRect(int ayah) {
    for (final (laid, planned) in _parts(ayah)) {
      if (planned.hasMarker) return laid.markerRect(ayah);
    }
    return null;
  }

  /// Where the page mark before [ayah] is drawn; null when it is not in this
  /// block.
  Rect? pageMarkRect(int ayah) {
    for (final segment in _segments) {
      if (segment.pageMarkRect(ayah) case final rect?) return rect;
    }
    return null;
  }

  /// The page numbers of the page marks in this block, by ayah.
  Map<int, int> get pageMarks => {
    for (final segment in _segments)
      for (final planned in segment.ayat)
        if (planned.pageMark)
          planned.number: plan.text.pageStarts[planned.number]!,
  };

  /// One rect per line for the ayah's text with its marker.
  List<Rect> ayahBoxes(int ayah) => [
    for (final (laid, planned) in _parts(ayah))
      ...laid.boxes(
        laid.offsetOf(planned, planned.textStart),
        laid.offsetOf(planned, planned.textEnd) + (planned.hasMarker ? 1 : 0),
      ),
  ];

  /// One rect per line for the ayah's text and its marker, the marker taken
  /// from its own slot ([markerRect]) and not from the paragraph's box for
  /// the placeholder, which can lie in another's slot (S1 finding 1). Two
  /// ayat that share a line never share the horizontal span of its rects.
  List<Rect> ayahLines(int ayah) {
    int lineOf(Rect rect) =>
        plan.lineAt(plan.blockTop(index) + rect.center.dy) - block.firstLine;
    final byLine = <int, Rect>{
      for (final (laid, planned) in _parts(ayah))
        for (final box in laid.boxes(
          laid.offsetOf(planned, planned.textStart),
          laid.offsetOf(planned, planned.textEnd),
        ))
          lineOf(box): box,
    };
    if (markerRect(ayah) case final marker?) {
      byLine.update(
        lineOf(marker),
        (box) => box.expandToInclude(marker),
        ifAbsent: () {
          final band = lineBand(lineOf(marker));
          return Rect.fromLTRB(
            marker.left,
            band.top,
            marker.right,
            band.bottom,
          );
        },
      );
    }
    return [for (final line in byLine.keys.toList()..sort()) byLine[line]!];
  }

  /// The rows of margin marks in this block (`RD-02`, `RD-15`, D-181), each
  /// with the rect its marks are drawn in: the block's width, the marks'
  /// height, its bottom a gap above the line in which the text of their
  /// ayah begins. None when the plan was made without rows.
  List<(List<MarginMark>, Rect)> get marginRows => [
    for (var line = 0; line < lineCount; line++)
      if (plan.marksAbove(block.firstLine + line) case final marks
          when marks.isNotEmpty)
        (
          marks,
          Rect.fromLTRB(
            0,
            lineBand(line).top - plan.rowExtent(block.firstLine + line),
            plan.width,
            lineBand(line).top - ReaderScreenMetrics.marginRowGap,
          ),
        ),
  ];

  /// Where each line starts, as the paragraphs broke them.
  List<LineStart> get laidLineStarts => [
    for (final segment in _segments) ...segment.laidLineStarts(),
  ];

  /// The left and right edges of each line as laid out, in block
  /// coordinates, unclamped: what a line really covers, its overhang too.
  List<(double, double)> get laidLineExtents => [
    for (final segment in _segments) ...segment.extents(),
  ];

  /// Where each line starts by the plan.
  List<LineStart> get plannedLineStarts => [
    for (var line = block.firstLine; line < block.endLine; line++)
      plan.lineStart(line),
  ];

  /// Whether the paragraphs broke every line where the plan did, each with
  /// one line height.
  bool get matchesPlan =>
      listEquals(laidLineStarts, plannedLineStarts) &&
      _segments.every(
        (segment) =>
            (segment.body.height - segment.segment.lineCount * plan.lineHeight)
                .abs() <
            _heightTolerance,
      );

  void paint(Canvas canvas, Offset offset) {
    for (final segment in _segments) {
      segment.paint(canvas, offset);
    }
  }

  /// The rect over all of the ayah's text and its marker in this block.
  Rect? ayahRect(int ayah) {
    final boxes = ayahBoxes(ayah);
    return boxes.isEmpty ? null : boxes.reduce((a, b) => a.expandToInclude(b));
  }

  void dispose() {
    for (final segment in _segments) {
      segment.dispose();
    }
  }

  /// The parts of the text of [ayah] this block holds, by paragraph.
  List<(_LaidSegment, PlannedAyah)> _parts(int ayah) => [
    for (final segment in _segments)
      for (final planned in segment.ayat)
        if (planned.number == ayah && planned.hasText) (segment, planned),
  ];
}

enum _Kind { pageMark, text, marker }

final class _Piece {
  const _Piece(this.kind, this.ayah, this.start, this.end);

  final _Kind kind;
  final int ayah;
  final int start;
  final int end;
}

/// One segment's paragraph placed in its block.
final class _LaidSegment {
  _LaidSegment(
    this.segment,
    this.ayat,
    this.body,
    this.twin,
    this.copies,
    this._drops,
    this.top,
    double markGap,
    this._width,
  ) {
    var at = 0;
    for (final planned in ayat) {
      if (planned.pageMark) {
        _pageMarkAt[planned.number] = _placeholders.length;
        _placeholders.add(_Piece(_Kind.pageMark, planned.number, at, ++at));
        _pieces.add(_placeholders.last);
      }
      if (!planned.hasText) continue;
      final length = planned.textEnd - planned.textStart;
      _textAt[planned.number] = at;
      if (length > 0) {
        _pieces.add(_Piece(_Kind.text, planned.number, at, at + length));
      }
      at += length;
      if (!planned.hasMarker) continue;
      _markerAt[planned.number] = _placeholders.length;
      _placeholders.add(_Piece(_Kind.marker, planned.number, at, ++at));
      _pieces.add(_placeholders.last);
    }
    _length = at;
    if (twin != null) {
      final last = body.computeLineMetrics().last;
      // The line ends with the last marker's slot, whose far gap is not ink:
      // centre what is drawn.
      shift = (_width - last.width - markGap) / 2 - last.left - _origin;
    }
  }

  final Segment segment;
  final List<PlannedAyah> ayat;
  final ui.Paragraph body;
  final ui.Paragraph? twin;

  /// The copies that draw the lines below a row of margin marks inside the
  /// paragraph, each with how far down they are moved.
  final List<(ui.Paragraph, double)> copies;

  /// How far each line is moved down by the rows above it in the paragraph.
  final List<double> _drops;
  final double top;
  final double _width;
  double shift = 0;
  final _pieces = <_Piece>[];
  final _placeholders = <_Piece>[];
  final _textAt = <int, int>{};
  final _markerAt = <int, int>{};
  final _pageMarkAt = <int, int>{};
  late final int _length;
  List<Rect>? _slots;

  PlannedAyah? planned(int ayah) {
    for (final planned in ayat) {
      if (planned.number == ayah && planned.hasText) return planned;
    }
    return null;
  }

  /// Whether this paragraph holds [offset] of [planned]'s ayah.
  bool holds(PlannedAyah planned, int offset) =>
      offset >= planned.textStart && offset < planned.textEnd;

  /// The paragraph offset of [offset] into [planned]'s ayah.
  int offsetOf(PlannedAyah planned, int offset) =>
      _textAt[planned.number]! + offset - planned.textStart;

  Rect markerRect(int ayah) => _childRect(_markerAt[ayah]!);

  int get _lastLine => segment.lineCount - 1;

  double _dx(int line) =>
      _origin + (twin != null && line == _lastLine ? shift : 0);

  double _dy(int line) => top + _drops[line];

  /// Where the paragraph's left edge lies in the block: lines keep to the
  /// right of a paragraph wider than the block, so it is moved left by the
  /// difference, its overhang and slack past the block's left edge.
  double get _origin => _width - body.width;

  int _lineAtY(double y) =>
      (y / (body.height / segment.lineCount)).floor().clamp(0, _lastLine);

  /// Boxes of a paragraph range, merged to one per line, in block
  /// coordinates, each held to its line's band and the block's width. A
  /// range's box can hold the hanging space at a line's end; it is cut at
  /// the block's edge.
  List<Rect> boxes(int start, int end) {
    final lineHeight = body.height / segment.lineCount;
    final width = _width;
    final byLine = <int, Rect>{};
    for (final box in body.getBoxesForRange(start, end)) {
      final line = _lineAtY((box.top + box.bottom) / 2);
      final dx = _dx(line);
      final rect = Rect.fromLTRB(
        math.max(box.left + dx, 0),
        _dy(line) + line * lineHeight,
        math.min(box.right + dx, width),
        _dy(line) + (line + 1) * lineHeight,
      );
      if (rect.width <= 0) continue;
      byLine.update(line, (r) => r.expandToInclude(rect), ifAbsent: () => rect);
    }
    return [for (final line in byLine.keys.toList()..sort()) byLine[line]!];
  }

  /// A page mark takes its whole slot, gaps and all, so that a page
  /// number wider than a marker still fits.
  Rect? pageMarkRect(int ayah) =>
      _pageMarkAt[ayah] == null ? null : _slot(_pageMarkAt[ayah]!);

  /// The slot placeholder [k] is drawn in. SkParagraph (Flutter 3.44) lays
  /// the placeholders of a right-to-left line out in the reverse of their
  /// order among themselves, each in another's slot, while the text between
  /// them keeps its place (S1 finding 1). Every slot is one size, so only
  /// which slot is whose is wrong: a line's placeholders, in order, take its
  /// slots from the right.
  Rect _slot(int k) {
    final slots = _slots ??= _assignSlots();
    return slots[k];
  }

  List<Rect> _assignSlots() {
    final boxes = [
      for (final box in body.getBoxesForPlaceholders()) box.toRect(),
    ];
    final byLine = <int, List<int>>{};
    for (final (k, box) in boxes.indexed) {
      byLine.putIfAbsent(_lineAtY(box.center.dy), () => []).add(k);
    }
    final slots = List<Rect>.filled(boxes.length, Rect.zero);
    for (final MapEntry(key: line, value: members) in byLine.entries) {
      final places = [for (final k in members) boxes[k]]
        ..sort((a, b) => b.left.compareTo(a.left));
      for (final (j, k) in members.indexed) {
        slots[k] = places[j].translate(_dx(line), _dy(line));
      }
    }
    return slots;
  }

  /// Where placeholder [k]'s mark is drawn: centred in its slot, which
  /// holds a gap on each side.
  Rect _childRect(int k) {
    final slot = _slot(k);
    return Rect.fromCenter(
      center: slot.center,
      width: slot.height,
      height: slot.height,
    );
  }

  List<LineStart> laidLineStarts() {
    final starts = <int>[if (segment.lineCount > 0) 0];
    final lines = body.computeLineMetrics().length;
    for (var k = 1; k < lines; k++) {
      var low = starts.last + 1;
      var high = _length;
      while (low < high) {
        final middle = (low + high) ~/ 2;
        if ((body.getLineNumberAt(middle) ?? lines) >= k) {
          high = middle;
        } else {
          low = middle + 1;
        }
      }
      starts.add(low);
    }
    return [for (final start in starts) _positionOf(start)];
  }

  LineStart _positionOf(int offset) {
    final piece = _pieces.lastWhere((p) => p.start <= offset);
    final index = piece.ayah - 1;
    return switch (piece.kind) {
      _Kind.pageMark => (ayah: index, offset: -1),
      _Kind.marker => (ayah: index, offset: planned(piece.ayah)!.units.length),
      _Kind.text => (
        ayah: index,
        offset: offset - piece.start + planned(piece.ayah)!.textStart,
      ),
    };
  }

  List<(double, double)> extents() => [
    for (final (k, line) in body.computeLineMetrics().indexed)
      (line.left + _dx(k), line.left + line.width + _dx(k)),
  ];

  void paint(Canvas canvas, Offset offset) {
    final origin = offset.translate(_origin, top);
    canvas.drawParagraph(body, origin);
    for (final (copy, drop) in copies) {
      canvas.drawParagraph(copy, origin.translate(0, drop));
    }
    if (twin case final twin?) {
      canvas.drawParagraph(twin, origin.translate(shift, _drops[_lastLine]));
    }
  }

  void dispose() {
    body.dispose();
    twin?.dispose();
    for (final (copy, _) in copies) {
      copy.dispose();
    }
  }
}

// Line heights are summed from measured parts; a difference below this is
// rounding.
const double _heightTolerance = 0.01;
