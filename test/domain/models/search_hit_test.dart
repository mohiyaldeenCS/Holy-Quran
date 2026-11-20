import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_range.dart';
import 'package:holyquran/domain/models/search_hit.dart';

void main() {
  test('a hit on the whole ayah that is not exact is refused', () {
    expect(
      () => SearchHit(
        ayah: QuranAddress('hafs', 1, 1),
        matches: [
          QuranRange(
            QuranAddress('hafs', 1, 1, 1),
            QuranAddress('hafs', 1, 1, 2),
          ),
        ],
        exact: false,
        gaps: 0,
        whole: true,
      ),
      throwsArgumentError,
    );
  });
}
