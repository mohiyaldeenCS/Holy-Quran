import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/recitation_file.dart';

void main() {
  final hash = 'a' * 64;
  RecitationFile file({
    int qualityKbps = 64,
    RecitationFilePart part = RecitationFilePart.ayah,
    int? surah = 1,
    int? ayah = 2,
    String path = '64/001002.mp3',
    int bytes = 10,
    String? sha256,
    Duration? duration = const Duration(milliseconds: 1500),
  }) => RecitationFile(
    qualityKbps: qualityKbps,
    part: part,
    surah: surah,
    ayah: ayah,
    path: path,
    bytes: bytes,
    sha256: sha256 ?? hash,
    duration: duration,
  );

  test('holds every field', () {
    final given = file();
    expect(given.qualityKbps, 64);
    expect(given.part, RecitationFilePart.ayah);
    expect(given.surah, 1);
    expect(given.ayah, 2);
    expect(given.path, '64/001002.mp3');
    expect(given.bytes, 10);
    expect(given.sha256, hash);
    expect(given.duration, const Duration(milliseconds: 1500));
    expect(file(duration: null).duration, isNull);
  });

  test('has a surah and ayah exactly as its part needs', () {
    expect(file(part: RecitationFilePart.surah, ayah: null).ayah, isNull);
    for (final part in [
      RecitationFilePart.basmala,
      RecitationFilePart.istiadha,
    ]) {
      expect(file(part: part, surah: null, ayah: null).surah, isNull);
      expect(() => file(part: part, ayah: null), throwsArgumentError);
      expect(() => file(part: part, surah: null), throwsArgumentError);
    }
    expect(() => file(part: RecitationFilePart.surah), throwsArgumentError);
    expect(() => file(ayah: null), throwsArgumentError);
    expect(() => file(surah: null), throwsArgumentError);
  });

  test('refuses numbers that are not positive', () {
    expect(() => file(qualityKbps: 0), throwsArgumentError);
    expect(() => file(surah: 0), throwsArgumentError);
    expect(() => file(ayah: 0), throwsArgumentError);
    expect(() => file(bytes: 0), throwsArgumentError);
    expect(() => file(duration: Duration.zero), throwsArgumentError);
  });

  test('takes a plain relative path only', () {
    for (final path in ['a.mp3', 'a/b-c_d.mp3', '64/001.mp3']) {
      expect(file(path: path).path, path);
    }
    for (final path in [
      '',
      '/a.mp3',
      'a/',
      'a//b',
      '../a.mp3',
      'a/./b',
      'a/..',
      'https://example.invalid/a.mp3',
      r'a\b',
      'a b',
      'a?b',
    ]) {
      expect(() => file(path: path), throwsArgumentError, reason: path);
    }
  });

  test('takes a lowercase hex SHA-256 only', () {
    for (final sha256 in ['A' * 64, 'a' * 63, 'g' * 64]) {
      expect(() => file(sha256: sha256), throwsArgumentError, reason: sha256);
    }
  });
}
