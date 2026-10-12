import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/playback_segment.dart';
import 'package:holyquran/domain/models/quran_address.dart';

void main() {
  test('a clip ends after it starts, at zero or later', () {
    expect(
      () =>
          SurahClip(1, const Duration(seconds: 2), const Duration(seconds: 2)),
      throwsArgumentError,
    );
    expect(
      () => SurahClip(1, const Duration(seconds: -1), Duration.zero),
      throwsArgumentError,
    );
    expect(
      SurahClip(1, Duration.zero, const Duration(seconds: 1)),
      SurahClip(1, Duration.zero, const Duration(seconds: 1)),
    );
  });

  test('silence is the only change withSilenceAfter makes', () {
    final segment = PlaybackSegment(
      kind: SegmentKind.ayah,
      address: QuranAddress.parse('x:2:3'),
      source: AyahFile(QuranAddress.parse('x:2:3')),
      repeat: 2,
      endsPage: true,
    );
    final silenced = segment.withSilenceAfter(const Duration(seconds: 5));
    expect(silenced.silenceAfter, const Duration(seconds: 5));
    expect(silenced.withSilenceAfter(Duration.zero), segment);
  });
}
