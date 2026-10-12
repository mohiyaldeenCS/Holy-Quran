import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/division_entry.dart';
import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/domain/models/quran_address.dart';

void main() {
  DivisionEntry entry({int number = 2, int page = 3}) => DivisionEntry(
    division: Division.hizb,
    number: number,
    firstAyah: QuranAddress('hafs', 2, 5),
    firstPage: page,
  );

  test('entries with the same fields are equal', () {
    expect(entry(), entry());
    expect(entry().hashCode, entry().hashCode);
    expect(entry(), isNot(entry(number: 3)));
    expect(entry(), isNot(entry(page: 4)));
  });

  test('names the unit, its first ayah and page', () {
    expect('${entry()}', 'DivisionEntry(hizb 2: hafs:2:5, page 3)');
  });
}
