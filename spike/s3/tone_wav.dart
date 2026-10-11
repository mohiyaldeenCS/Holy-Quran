import 'dart:math' as math;
import 'dart:typed_data';

const toneBeepEvery = Duration(seconds: 10);
const toneBeepLength = Duration(milliseconds: 250);

const _wavHeaderBytes = 44;
const _toneHz = 220.0;
const _toneLevel = 0.03;
const _beepHz = 1000.0;
const _beepLevel = 0.3;
const _beepRamp = Duration(milliseconds: 5);

/// A mono 16-bit PCM WAV: a quiet low tone with a louder high beep
/// at the start of every [toneBeepEvery], so a gap in playback is audible.
Uint8List toneWav({required Duration length, int sampleRate = 16000}) {
  final samples = _sampleCount(length, sampleRate);
  final dataBytes = samples * 2;
  final bytes = ByteData(_wavHeaderBytes + dataBytes);
  _writeAscii(bytes, 0, 'RIFF');
  bytes.setUint32(4, 36 + dataBytes, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');
  _writeAscii(bytes, 12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  _writeAscii(bytes, 36, 'data');
  bytes.setUint32(40, dataBytes, Endian.little);

  final every = toneBeepEvery.inMicroseconds * sampleRate ~/ 1000000;
  final beep = toneBeepLength.inMicroseconds * sampleRate ~/ 1000000;
  final ramp = _beepRamp.inMicroseconds * sampleRate ~/ 1000000;
  for (var i = 0; i < samples; i++) {
    final t = i / sampleRate;
    final inCycle = i % every;
    double value;
    if (inCycle < beep) {
      final edge = math.min(inCycle, beep - 1 - inCycle);
      final gain = edge < ramp ? edge / ramp : 1.0;
      value = _beepLevel * gain * math.sin(2 * math.pi * _beepHz * t);
    } else {
      value = _toneLevel * math.sin(2 * math.pi * _toneHz * t);
    }
    bytes.setInt16(
      _wavHeaderBytes + i * 2,
      (value * 32767).round(),
      Endian.little,
    );
  }
  return bytes.buffer.asUint8List();
}

int toneWavSize({required Duration length, int sampleRate = 16000}) =>
    _wavHeaderBytes + _sampleCount(length, sampleRate) * 2;

int _sampleCount(Duration length, int sampleRate) =>
    length.inMicroseconds * sampleRate ~/ 1000000;

void _writeAscii(ByteData bytes, int offset, String text) {
  for (var i = 0; i < text.length; i++) {
    bytes.setUint8(offset + i, text.codeUnitAt(i));
  }
}
