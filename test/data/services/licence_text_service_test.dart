import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/services/licence_text_service.dart';
import 'package:holyquran/utils/result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads the three OFL texts unchanged, in file-name order', () async {
    final result = await AssetLicenceTextService().fontLicences();

    final texts = (result as Ok<List<String>>).value;
    final files =
        Directory('assets/licenses').listSync().whereType<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(3));
    expect(texts, [for (final file in files) file.readAsStringSync()]);
    for (final text in texts) {
      expect(text, contains('SIL OPEN FONT LICENSE'));
    }
  });
}
