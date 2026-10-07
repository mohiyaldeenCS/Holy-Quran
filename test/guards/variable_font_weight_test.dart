import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../testing/fonts.dart';

// Synthetic text, not Quran text.
const _sample = 'نص تجريبي';
const _ink = TextStyle(fontSize: 48, color: Color(0xFF000000));
const _kufi = TextStyle(fontFamily: 'Reem Kufi');

Future<Uint8List> _render(TextStyle style) async {
  final painter = TextPainter(
    text: TextSpan(text: _sample, style: _ink.merge(style)),
    textDirection: TextDirection.rtl,
  )..layout();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawColor(const Color(0xFFFFFFFF), BlendMode.src);
  painter.paint(canvas, const Offset(8, 8));
  final picture = recorder.endRecording();
  final image = await picture.toImage(400, 120);
  final bytes = await image.toByteData();
  image.dispose();
  picture.dispose();
  painter.dispose();
  return bytes!.buffer.asUint8List();
}

Future<Uint8List> _byWeight(FontWeight weight) =>
    _render(_kufi.copyWith(fontWeight: weight));

Future<Uint8List> _byAxis(double wght) => _render(
  _kufi.copyWith(
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', wght)],
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Type question 2 of docs/DESIGN_SYSTEM.md: Reem Kufi is a variable font
  // (wght 400–700). On this Flutter, fontWeight alone moves the wght axis, so
  // the generated styles need no fontVariations.
  group('Reem Kufi', () {
    setUpAll(loadAppFonts);

    test('draws its own glyphs, not the test font', () async {
      final kufi = await _byWeight(FontWeight.w400);
      expect(kufi.any((byte) => byte != 0xFF), isTrue);
      expect(kufi, isNot(equals(await _render(const TextStyle()))));
    });

    test('fontWeight changes the drawing', () async {
      final regular = await _byWeight(FontWeight.w400);
      expect(await _byWeight(FontWeight.w600), isNot(equals(regular)));
      expect(await _byWeight(FontWeight.w700), isNot(equals(regular)));
      expect(
        await _byWeight(FontWeight.w700),
        isNot(equals(await _byWeight(FontWeight.w600))),
      );
    });

    test('w700 draws the same pixels as w400 with wght 700', () async {
      expect(await _byWeight(FontWeight.w700), equals(await _byAxis(700)));
    });

    test('w600 draws the same pixels as w400 with wght 600', () async {
      expect(await _byWeight(FontWeight.w600), equals(await _byAxis(600)));
    });
  });
}
