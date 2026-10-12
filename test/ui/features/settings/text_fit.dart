import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Draws on a small phone, 360 wide, with the system text at 200%.
void usePhoneAtDoubleText(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(360, 640)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Expects every word of the text [finder] finds to fit its line, so that
/// the text wraps only between words.
void expectWordsFit(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final text = paragraph.text.toPlainText();
  for (final word in text.split(RegExp(r'\s+'))) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: paragraph.text.style),
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
    )..layout();
    expect(
      painter.width,
      lessThanOrEqualTo(paragraph.constraints.maxWidth),
      reason: '«$word» of «$text»',
    );
    painter.dispose();
  }
}
