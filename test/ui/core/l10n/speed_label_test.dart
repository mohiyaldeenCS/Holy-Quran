import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/speed_label.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  test('writes every speed with Arabic-Indic digits, the Arabic decimal '
      'separator and at least one decimal', () {
    expect(
      [for (final speed in PlaybackSpeed.all) speedLabel(_l10n, speed)],
      ['٠٫٥×', '٠٫٧٥×', '١٫٠×', '١٫٢٥×', '١٫٥×', '١٫٧٥×', '٢٫٠×'],
    );
  });
}
