@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/core/widgets/home_header.dart';

import '../../../../testing/golden.dart';

void main() {
  testWidgets('with and without search, in each theme', (tester) async {
    await expectGoldensInThemes(
      tester,
      'home_header',
      (context) => SizedBox(
        width: 350,
        child: goldenColumn([HomeHeader(onSearch: () {}), const HomeHeader()]),
      ),
      surfaceSize: const Size(390, 160),
    );
  });
}
