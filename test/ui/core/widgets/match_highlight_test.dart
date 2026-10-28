import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/search_match.dart';
import 'package:holyquran/ui/core/widgets/match_highlight.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';

import '../../../../testing/golden.dart';

// Synthetic, never Quran text. Spaces at both ends and a double space inside
// would be lost to any trimming or normalising.
const _sample = ' نص تجريبي  للاختبار ';
const _packSample = PackText.fromPack(_sample);

Future<void> _pump(
  WidgetTester tester,
  List<SearchMatch> matches, {
  double width = 300,
}) => tester.pumpWidget(
  goldenApp(
    ReadingTheme.paper,
    SizedBox(
      width: width,
      child: QuranText(
        _packSample,
        size: QuranTextSize.compact,
        align: QuranTextAlign.start,
        matches: matches,
      ),
    ),
  ),
);

RenderMatchHighlight _highlight(WidgetTester tester) =>
    tester.renderObject<RenderMatchHighlight>(find.byType(MatchHighlight));

void main() {
  testWidgets('paints one rect for a match and leaves the string whole', (
    tester,
  ) async {
    await _pump(tester, const [SearchMatch(start: 1, end: 3)]);

    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    expect(paragraph.text.toPlainText(), _sample);
    expect((paragraph.text as TextSpan).children, isNull);
    final rects = _highlight(tester).rects;
    expect(rects, hasLength(1));
    expect(rects.single.width, greaterThan(0));
    expect(rects.single.height, lessThanOrEqualTo(paragraph.size.height));
    expect(rects.single.height, greaterThan(0));
  });

  testWidgets('paints a rect for each line a match covers', (tester) async {
    await _pump(tester, const [
      SearchMatch(start: 0, end: _sample.length),
    ], width: 60);

    expect(_highlight(tester).rects.length, greaterThan(1));
  });

  testWidgets('with no match there is nothing to paint', (tester) async {
    await _pump(tester, const []);

    expect(find.byType(MatchHighlight), findsNothing);
  });

  testWidgets('follows the matches it is given', (tester) async {
    await _pump(tester, const [SearchMatch(start: 1, end: 3)]);
    await _pump(tester, const [
      SearchMatch(start: 1, end: 3),
      SearchMatch(start: 8, end: 10),
    ]);

    expect(_highlight(tester).rects, hasLength(2));
  });
}
