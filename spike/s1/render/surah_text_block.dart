import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:holyquran/domain/models/mark_span.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/word_span.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'highlight_painter.dart';
import 'surah_paragraph.dart';

/// Surah-mode text: consecutive ayat flowing in one justified paragraph in
/// the style of `QuranText` at the page size (Amiri Quran, `quran-ink`,
/// right to left, Arabic, 25 / 2.3 with even leading, never bold), with
/// [markers], one `AyahMarker` per ayah, inline after each ayah, and
/// [pageMarks] inline before the ayah each names (RD-06, D-071).
///
/// [highlighted] holds ayah and word addresses (the recitation) and
/// [selected] ayah addresses (`.qk-hl-select`); both are painted under the
/// text and never change it. The block takes no gestures: a
/// `BlockGestures` around it resolves them from its geometry (D-095). The
/// last line is centred when [centreLastLine], as `text-align-last:
/// center` of `.qk-quran-page`.
/// [startOffset] and [maxLines] let a block continue the line flow of the
/// block before it and stop on a full line (`page_blocks_v2.dart`).
final class SurahTextBlock extends MultiChildRenderObjectWidget {
  SurahTextBlock({
    required this.firstAyah,
    required this.ayat,
    required this.words,
    required List<Widget> markers,
    this.marks,
    this.basmala,
    this.highlighted = const {},
    this.selected = const {},
    this.centreLastLine = true,
    this.startOffset = 0,
    Map<QuranAddress, Widget> pageMarks = const {},
    this.wordColours = const {},
    this.maxLines,
    this.leadInLines = 0,
    super.key,
  }) : pageMarkAyat = (pageMarks.keys.toList()..sort()),
       super(
         children: [
           ...markers,
           for (final ayah in pageMarks.keys.toList()..sort()) pageMarks[ayah]!,
         ],
       ) {
    if (markers.length != ayat.length) {
      throw ArgumentError('one marker per ayah');
    }
  }

  final QuranAddress firstAyah;
  final List<PackText> ayat;
  final List<List<WordSpan>> words;

  /// The marks of each ayah (D-083); a line or a block may start at one.
  /// Null for none.
  final List<List<MarkSpan>>? marks;
  final PackText? basmala;
  final Set<QuranAddress> highlighted;

  /// Selected ayat, by ayah address.
  final Set<QuranAddress> selected;
  final bool centreLastLine;
  final int startOffset;
  final List<QuranAddress> pageMarkAyat;
  final Map<QuranAddress, Color> wordColours;
  final int? maxLines;

  /// Lines laid out before the shown ones and hidden: the end of the block
  /// before, so that the first shown words keep their shaping.
  final int leadInLines;

  SurahBlockContent get _content => SurahBlockContent(
    firstAyah: firstAyah,
    ayat: ayat,
    words: words,
    marks: marks,
    basmala: basmala,
    startOffset: startOffset,
    pageMarks: pageMarkAyat.toSet(),
    wordColours: wordColours,
  );

  @override
  RenderSurahTextBlock createRenderObject(BuildContext context) =>
      RenderSurahTextBlock(
        content: _content,
        style: _styleOf(context),
        textScaler: MediaQuery.textScalerOf(context),
        colors: context.colors,
        highlighted: highlighted,
        selected: selected,
        centreLastLine: centreLastLine,
        maxLines: maxLines,
        leadInLines: leadInLines,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSurahTextBlock renderObject,
  ) => renderObject
    ..content = _content
    ..style = _styleOf(context)
    ..textScaler = MediaQuery.textScalerOf(context)
    ..colors = context.colors
    ..highlighted = highlighted
    ..selected = selected
    ..centreLastLine = centreLastLine
    ..maxLines = maxLines
    ..leadInLines = leadInLines;

  static TextStyle _styleOf(BuildContext context) =>
      AppTextStyles.quranPage.copyWith(color: context.colors.quranInk);
}

final class _BlockChildData extends ContainerBoxParentData<RenderBox> {}

/// Lays out a [SurahTextBlock]: markers and page marks are measured first,
/// their sizes become the paragraph's placeholders, and each is then placed
/// on its placeholder. Highlights, text, then marks are painted in that
/// order.
final class RenderSurahTextBlock extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BlockChildData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BlockChildData> {
  RenderSurahTextBlock({
    required this._content,
    required this._style,
    required this._textScaler,
    required this._colors,
    required this._highlighted,
    required this._selected,
    required this._centreLastLine,
    required this._maxLines,
    required this._leadInLines,
  });

  SurahParagraph? _paragraph;
  List<Size> _childSizes = const [];

  SurahBlockContent _content;
  set content(SurahBlockContent value) {
    if (value.sameAs(_content)) return;
    _content = value;
    _relayout();
  }

  TextStyle _style;
  set style(TextStyle value) {
    if (value == _style) return;
    _style = value;
    _relayout();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _relayout();
  }

  AppColors _colors;
  set colors(AppColors value) {
    if (value == _colors) return;
    _colors = value;
    markNeedsPaint();
  }

  Set<QuranAddress> _highlighted;
  set highlighted(Set<QuranAddress> value) {
    if (setEquals(value, _highlighted)) return;
    _highlighted = value;
    markNeedsPaint();
  }

  Set<QuranAddress> _selected;
  set selected(Set<QuranAddress> value) {
    if (setEquals(value, _selected)) return;
    _selected = value;
    markNeedsPaint();
  }

  bool _centreLastLine;
  set centreLastLine(bool value) {
    if (value == _centreLastLine) return;
    _centreLastLine = value;
    _relayout();
  }

  int? _maxLines;
  set maxLines(int? value) {
    if (value == _maxLines) return;
    _maxLines = value;
    _relayout();
  }

  int _leadInLines;
  set leadInLines(int value) {
    if (value == _leadInLines) return;
    _leadInLines = value;
    _relayout();
  }

  /// The laid-out paragraph, for checks and measurement.
  SurahParagraph get paragraph => _paragraph!;

  List<Rect> boxesOf(QuranAddress address) =>
      _paragraph?.boxesOf(address) ?? const [];

  double? topOf(QuranAddress ayah) => _paragraph?.topOf(ayah);

  List<int> get lineStarts => _paragraph?.lineStarts ?? const [];

  void _relayout() {
    _paragraph?.dispose();
    _paragraph = null;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BlockChildData) {
      child.parentData = _BlockChildData();
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final paragraph = _build([
      for (var child = firstChild; child != null; child = childAfter(child))
        child.getDryLayout(const BoxConstraints()),
    ])..layout(constraints.maxWidth);
    final size = constraints.constrain(
      Size(constraints.maxWidth, paragraph.height),
    );
    paragraph.dispose();
    return size;
  }

  @override
  void performLayout() {
    if (!constraints.hasBoundedWidth) {
      throw FlutterError('SurahTextBlock needs a bounded width.');
    }
    final sizes = <Size>[];
    for (var child = firstChild; child != null; child = childAfter(child)) {
      child.layout(const BoxConstraints(), parentUsesSize: true);
      sizes.add(child.size);
    }
    final width = constraints.maxWidth;
    if (_paragraph == null ||
        _paragraph!.width != width ||
        !listEquals(sizes, _childSizes)) {
      _paragraph?.dispose();
      _paragraph = _build(sizes)..layout(width);
      _childSizes = sizes;
    }
    final paragraph = _paragraph!;
    size = constraints.constrain(Size(width, paragraph.height));
    var index = 0;
    final marks = _content.pageMarkIndices;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      (child.parentData! as _BlockChildData).offset = index < _content.length
          ? paragraph.markerRect(index).topLeft
          : paragraph.pageMarkRect(marks[index - _content.length]).topLeft;
      index++;
    }
  }

  SurahParagraph _build(List<Size> sizes) => SurahParagraph(
    _content,
    style: _style,
    textScaler: _textScaler,
    markerSizes: sizes.sublist(0, _content.length),
    pageMarkSizes: sizes.sublist(_content.length),
    centreLastLine: _centreLastLine,
    maxLines: _maxLines,
    leadInLines: _leadInLines,
  );

  /// The shown boxes of [ayah], and whether its start and its marker are
  /// in them: an ayah that runs on from the block before, or past the
  /// block's last shown line, is open there.
  static SelectedAyah _selectionOf(
    SurahParagraph paragraph,
    QuranAddress ayah,
  ) {
    final index = paragraph.content.indexOf(ayah)!;
    return (
      boxes: paragraph.boxesOf(ayah),
      starts: paragraph.topOf(ayah) != null,
      ends: paragraph.isVisible(paragraph.markerRect(index)),
    );
  }

  bool _shows(RenderBox child) {
    final offset = (child.parentData! as _BlockChildData).offset;
    return paragraph.isVisible(offset & child.size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final paragraph = _paragraph!;
    final ayat = <List<Rect>>[];
    final words = <Rect>[];
    for (final address in _highlighted) {
      final boxes = paragraph.boxesOf(address);
      if (boxes.isEmpty) continue;
      if (address.isWord) {
        words.addAll(boxes);
      } else {
        ayat.add(boxes);
      }
    }
    paintHighlights(
      context.canvas,
      offset,
      colors: _colors,
      ayat: ayat,
      words: words,
      selected: [
        for (final ayah in _selected)
          if (!ayah.isWord && paragraph.content.indexOf(ayah) != null)
            _selectionOf(paragraph, ayah),
      ].where((ayah) => ayah.boxes.isNotEmpty),
      width: size.width,
    );
    paragraph.paint(context.canvas, offset);
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (_shows(child)) {
        context.paintChild(
          child,
          (child.parentData! as _BlockChildData).offset + offset,
        );
      }
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (_shows(child)) visitor(child);
    }
  }

  @override
  bool hitTestSelf(Offset position) => size.contains(position);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (var child = lastChild; child != null; child = childBefore(child)) {
      if (!_shows(child)) continue;
      final offset = (child.parentData! as _BlockChildData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformed) =>
            child!.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _paragraph?.dispose();
    super.dispose();
  }
}
