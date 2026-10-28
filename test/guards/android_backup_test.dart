import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _manifest = 'android/app/src/main/AndroidManifest.xml';
const _rules = 'android/app/src/main/res/xml/data_extraction_rules.xml';

// Every storage domain of Android's backup rules, the device-protected ones
// included.
const _domains = [
  'root',
  'file',
  'database',
  'sharedpref',
  'external',
  'device_root',
  'device_file',
  'device_database',
  'device_sharedpref',
];

String _application(String manifest) =>
    RegExp(r'<application\b[^>]*>').firstMatch(manifest)?[0] ?? '';

List<String> _excluded(String rules, String section) {
  final body = RegExp(
    '<$section>(.*?)</$section>',
    dotAll: true,
  ).firstMatch(rules)?[1];
  return [
    for (final match in RegExp(
      r'<exclude\s+domain="(\w+)"\s*/>',
    ).allMatches(body ?? ''))
      match[1]!,
  ];
}

// The user's database holds reading history, bookmarks and notes, which are
// local by default (CLAUDE.md; docs/ARCHITECTURE.md, "Privacy and security").
void main() {
  final application = _application(File(_manifest).readAsStringSync());

  test('the app turns Android backup off', () {
    expect(application, contains('android:allowBackup="false"'));
    expect(application, contains('android:fullBackupContent="false"'));
  });

  test('the app names its data extraction rules for Android 12 and later', () {
    expect(
      application,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });

  for (final section in ['cloud-backup', 'device-transfer']) {
    test('$section excludes every domain', () {
      final rules = File(_rules).readAsStringSync();

      expect(_excluded(rules, section), unorderedEquals(_domains));
      expect(rules, isNot(contains('<include')));
    });
  }
}
