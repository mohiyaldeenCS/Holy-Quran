import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/search_hit.dart';

void main() {
  final ayah = QuranAddress('hafs', 1, 1);
  final words = QuranRange(
    QuranAddress('hafs', 1, 1, 1),
    QuranAddress('hafs', 1, 1, 2),
  );

  test('a hit on the whole ayah is exact', () {
    expect(
      SearchHit(
        ayah: ayah,
        matches: [words],
        exact: true,
        gaps: 0,
        whole: true,
      ).whole,
      isTrue,
    );
    expect(
      () => SearchHit(
        ayah: ayah,
        matches: [words],
        exact: false,
        gaps: 0,
        whole: true,
      ),
      throwsArgumentError,
    );
  });
}
