import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/catalogue_config.dart';

void main() {
  test('the catalogue address is empty or an https catalogue.json', () {
    switch (catalogueUrl) {
      case null:
        expect(catalogueAddress, isEmpty);
      case final url:
        expect(url.scheme, 'https');
        expect(url.host, isNotEmpty);
        expect(url.pathSegments.last, 'catalogue.json');
        expect(url.hasQuery || url.hasFragment, isFalse);
    }
  });
}
