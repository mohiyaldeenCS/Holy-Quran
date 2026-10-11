@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/ui/core/widgets/continue_listening_row.dart';

import '../../../../testing/golden.dart';

// Synthetic name and reciter.
const _name = PackText.fromPack('اسم تجريبي');
const _reciter = 'قارئ تجريبي';

void main() {
  testWidgets('with and without a reciter, in each theme', (tester) async {
    await expectGoldensInThemes(
      tester,
      'continue_listening_row',
      (context) => SizedBox(
        width: 350,
        child: goldenColumn([
          ContinueListeningRow(
            surahName: _name,
            ayah: 10,
            reciter: _reciter,
            onPlay: () {},
          ),
          ContinueListeningRow(surahName: _name, ayah: 10, onPlay: () {}),
        ]),
      ),
      surfaceSize: const Size(390, 240),
    );
  });
}
