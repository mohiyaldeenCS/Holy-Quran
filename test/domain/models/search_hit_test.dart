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

  test('occurrences are the matches unless given, and never more', () {
    SearchHit hit({int? occurrences}) => SearchHit(
      ayah: QuranAddress('hafs', 1, 1),
      matches: [
        for (final word in [1, 3])
          QuranRange(
            QuranAddress('hafs', 1, 1, word),
            QuranAddress('hafs', 1, 1, word),
          ),
      ],
      exact: false,
      gaps: 1,
      occurrences: occurrences,
    );
    expect(hit().occurrences, 2);
    expect(hit(occurrences: 1).occurrences, 1);
    expect(() => hit(occurrences: 0), throwsArgumentError);
    expect(() => hit(occurrences: 3), throwsArgumentError);
  });
}
