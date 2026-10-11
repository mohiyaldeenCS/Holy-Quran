import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'tone_wav.dart';

void main() {
  const rate = 16000;
  const length = Duration(seconds: 41);
  final wav = toneWav(length: length);
  final data = ByteData.sublistView(wav);

  String ascii(int offset) =>
      String.fromCharCodes(wav.sublist(offset, offset + 4));

  double rms(Duration from, Duration span) {
    final start = from.inMicroseconds * rate ~/ 1000000;
    final count = span.inMicroseconds * rate ~/ 1000000;
    var sum = 0.0;
    for (var i = start; i < start + count; i++) {
      final v = data.getInt16(44 + i * 2, Endian.little) / 32768;
      sum += v * v;
    }
    return math.sqrt(sum / count);
  }

  test('header describes mono 16-bit PCM at the sample rate', () {
    expect(ascii(0), 'RIFF');
    expect(data.getUint32(4, Endian.little), wav.length - 8);
    expect(ascii(8), 'WAVE');
    expect(ascii(12), 'fmt ');
    expect(data.getUint32(16, Endian.little), 16);
    expect(data.getUint16(20, Endian.little), 1);
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(24, Endian.little), rate);
    expect(data.getUint32(28, Endian.little), rate * 2);
    expect(data.getUint16(32, Endian.little), 2);
    expect(data.getUint16(34, Endian.little), 16);
    expect(ascii(36), 'data');
    expect(data.getUint32(40, Endian.little), wav.length - 44);
  });

  test('length is exactly the requested duration', () {
    expect(wav.length, 44 + 41 * rate * 2);
    expect(toneWavSize(length: length), wav.length);
    final other = toneWav(length: const Duration(seconds: 2), sampleRate: 8000);
    expect(other.length, 44 + 2 * 8000 * 2);
    expect(
      toneWavSize(length: const Duration(seconds: 2), sampleRate: 8000),
      other.length,
    );
  });

  test('a loud beep starts every 10 s and the tone between is quiet', () {
    const window = Duration(milliseconds: 50);
    final beepMiddle = toneBeepLength ~/ 2;
    for (var k = 0; k <= 4; k++) {
      final start = toneBeepEvery * k;
      expect(
        rms(start + beepMiddle, window),
        greaterThan(0.15),
        reason: 'beep $k',
      );
      expect(
        rms(start + toneBeepLength + window, window),
        lessThan(0.03),
        reason: 'after beep $k',
      );
      if (k == 4) continue;
      expect(
        rms(start + const Duration(seconds: 5), window),
        lessThan(0.03),
        reason: 'between $k',
      );
      expect(
        rms(start + const Duration(seconds: 5), window),
        greaterThan(0.01),
        reason: 'tone $k',
      );
    }
    expect(
      rms(const Duration(seconds: 9, milliseconds: 900), window),
      lessThan(0.03),
    );
  });
}
