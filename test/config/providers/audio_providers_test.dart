import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/audio_providers.dart';
import 'package:holyquran/data/repositories/player_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/domain/models/player_state.dart';
import 'package:provider/provider.dart';

import '../../../testing/fakes/fake_quran_index_repository.dart';

Future<BuildContext> _contextBelow(
  WidgetTester tester,
  List<AreaSetup> areas,
) async {
  final providers = await buildDependencies(areas: areas);
  late BuildContext below;
  await tester.pumpWidget(
    MultiProvider(
      providers: providers,
      child: Builder(
        builder: (context) {
          below = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return below;
}

void main() {
  testWidgets('provides the player without touching a plugin once the base '
      'pack serves, and none before', (tester) async {
    expect(await buildDependencies(areas: [audioProviders]), isEmpty);

    final withPack = await _contextBelow(tester, [
      (dependencies) async => dependencies.provide<QuranIndexRepository>(
        FakeQuranIndexRepository.synthetic(),
      ),
      audioProviders,
    ]);
    final player = withPack.read<PlayerRepository>();
    expect(player.state.speed, PlaybackSpeed.normal);
    expect(player, isA<EnginePlayerRepository>());
  });
}
