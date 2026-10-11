@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/search_summary.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('a title, a count line and the sort control', (tester) async {
    await expectGoldensInThemes(tester, 'search_summary', (context) {
      final l10n = AppLocalizations.of(context);
      return SizedBox(
        width: 420,
        child: SearchSummary(
          title: l10n.sampleSearchTitle,
          count: l10n.sampleSearchCount,
          sortLabel: l10n.searchSortMushafOrder,
          onSort: () {},
        ),
      );
    }, surfaceSize: const Size(460, 100));
  });
}
