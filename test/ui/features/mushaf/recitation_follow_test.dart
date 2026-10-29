import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/player_state.dart';
import 'package:holyquran/ui/features/mushaf/view_models/recitation_follow.dart';

import '../../../../testing/fakes/fake_player_repository.dart';
import 'recitation_fixture.dart';

void main() {
  late FakePlayerRepository player;
  late RecitationFollow follow;
  var notified = 0;

  setUp(() {
    notified = 0;
    player = FakePlayerRepository();
    follow = RecitationFollow(player)..addListener(() => notified++);
    addTearDown(follow.dispose);
  });

  test('nothing is recited before a recitation', () {
    expect(follow.recited, isNull);
    expect(follow.showReturn, isFalse);
    expect(follow.request, isNull);
    expect(follow.following, isTrue);
  });

  test('without a player nothing is recited or asked', () {
    final alone = RecitationFollow(null);
    addTearDown(alone.dispose);
    alone
      ..userScrolled()
      ..resume();

    expect(alone.recited, isNull);
    expect(alone.showReturn, isFalse);
    expect(alone.request, isNull);
  });

  test('the recited ayah moves with the ayah events and asks to be shown', () {
    final plan = recitationPlan();
    player.reach(plan, ayahSegment(2, 5));

    expect(follow.recited, ayahAt(2, 5));
    expect(follow.request!.address, ayahAt(2, 5));

    final first = follow.request;
    player.reach(plan, ayahSegment(2, 6), index: 1);

    expect(follow.recited, ayahAt(2, 6));
    expect(follow.request!.address, ayahAt(2, 6));
    expect(follow.request, isNot(same(first)));
  });

  test('a repeated ayah asks once', () {
    final plan = recitationPlan();
    player.reach(plan, ayahSegment(2, 5));
    final request = follow.request;
    player.reach(plan, ayahSegment(2, 5), index: 1);

    expect(follow.request, same(request));
  });

  test('a basmala keeps the ayah before it and names none of its own', () {
    final plan = recitationPlan();
    player.reach(plan, ayahSegment(2, 40));
    player.reach(plan, basmalaSegment(3), index: 1);

    expect(follow.recited, ayahAt(2, 40));
    player.reach(plan, ayahSegment(3, 1), index: 2);
    expect(follow.recited, ayahAt(3, 1));
  });

  for (final speed in PlaybackSpeed.all) {
    test('at ${speed.factor}x the highlight follows the events alone', () async {
      final plan = recitationPlan();
      player.reach(plan, ayahSegment(2, 1));
      await player.setSpeed(speed);
      final request = follow.request;
      final heard = notified;

      // A change of speed changes no ayah: nothing moves and nothing is asked.
      expect(player.state.speed, speed);
      expect(follow.recited, ayahAt(2, 1));
      expect(follow.request, same(request));
      expect(notified, heard);

      player.reach(plan, ayahSegment(2, 2), index: 1);
      expect(player.state.speed, speed);
      expect(follow.recited, ayahAt(2, 2));
      expect(follow.request!.address, ayahAt(2, 2));
    });
  }

  test('pausing keeps the ayah and stopping clears it', () async {
    final plan = recitationPlan();
    player.reach(plan, ayahSegment(2, 5));
    await player.pause();

    expect(follow.recited, ayahAt(2, 5));
    expect(follow.playing, isFalse);

    await player.resume();
    expect(follow.playing, isTrue);

    await player.stop();
    expect(follow.recited, isNull);
    expect(follow.showReturn, isFalse);
    expect(follow.playing, isFalse);
  });

  test('a scroll of the user stops following and offers the way back', () {
    final plan = recitationPlan();
    player.reach(plan, ayahSegment(2, 5));
    follow.userScrolled();

    expect(follow.following, isFalse);
    expect(follow.showReturn, isTrue);

    final request = follow.request;
    player.reach(plan, ayahSegment(2, 6), index: 1);

    expect(follow.recited, ayahAt(2, 6));
    expect(follow.request, same(request));
    expect(follow.showReturn, isTrue);
  });

  test('returning follows again and asks for the ayah being recited', () {
    final plan = recitationPlan();
    player.reach(plan, ayahSegment(2, 5));
    follow.userScrolled();
    player.reach(plan, ayahSegment(2, 9), index: 1);

    follow.resume();

    expect(follow.following, isTrue);
    expect(follow.showReturn, isFalse);
    expect(follow.request!.address, ayahAt(2, 9));
    player.reach(plan, ayahSegment(2, 10), index: 2);
    expect(follow.request!.address, ayahAt(2, 10));
  });

  test('a scroll with nothing recited stops nothing', () {
    follow.userScrolled();
    player.reach(recitationPlan(), ayahSegment(2, 5));

    expect(follow.following, isTrue);
    expect(follow.request!.address, ayahAt(2, 5));
  });

  test('a plan that reaches another ayah follows again', () async {
    final plan = recitationPlan();
    player.reach(plan, ayahSegment(2, 5));
    follow.userScrolled();

    final next = recitationPlan();
    await player.play(next);
    expect(follow.following, isFalse);
    player.reach(next, ayahSegment(2, 30));

    expect(follow.following, isTrue);
    expect(follow.showReturn, isFalse);
    expect(follow.request!.address, ayahAt(2, 30));
  });

  test('a plan rebuilt at the ayah being recited goes on as it was', () async {
    player.reach(recitationPlan(), ayahSegment(2, 5));
    follow.userScrolled();
    final request = follow.request;

    final rebuilt = recitationPlan();
    await player.play(rebuilt);
    player.reach(rebuilt, ayahSegment(2, 5));

    expect(follow.following, isFalse);
    expect(follow.showReturn, isTrue);
    expect(follow.recited, ayahAt(2, 5));
    expect(follow.request, same(request));
  });

  test('a plan after playback stopped follows again', () async {
    player.reach(recitationPlan(), ayahSegment(2, 5));
    follow.userScrolled();
    await player.stop();

    final next = recitationPlan();
    await player.play(next);
    player.reach(next, ayahSegment(2, 5));

    expect(follow.following, isTrue);
    expect(follow.request!.address, ayahAt(2, 5));
  });

  test('the ayah the player holds from the plan before is not new', () {
    final old = recitationPlan();
    player.reach(old, ayahSegment(2, 40));
    final next = recitationPlan();

    // The player gives the new plan before its first segment.
    player.state = PlayerState(
      plan: next,
      segment: player.state.segment,
      segmentIndex: 0,
      ayah: player.state.ayah,
    );
    expect(follow.recited, ayahAt(2, 40));

    player.reach(next, basmalaSegment(3));
    expect(follow.recited, ayahAt(2, 40));
    expect(follow.heard, ayahAt(3, 1));

    player.reach(next, ayahSegment(3, 1), index: 1);
    expect(follow.recited, ayahAt(3, 1));
  });

  test('a plan after none starts with no ayah of the one before', () {
    final next = recitationPlan();
    player.state = PlayerState(plan: next, segment: basmalaSegment(3));

    expect(follow.recited, isNull);
    expect(follow.heard, ayahAt(3, 1));
  });

  test('a recitation served as whole surahs shows nothing', () {
    final plan = recitationPlan(boundaries: false);
    player.reach(plan, surahSegment(2));

    expect(follow.recited, isNull);
    expect(follow.request, isNull);
    expect(follow.showReturn, isFalse);
    expect(follow.playing, isTrue);

    follow.userScrolled();
    expect(follow.showReturn, isFalse);
  });

  test('a recitation served as whole surahs does not inherit an ayah', () {
    player.reach(recitationPlan(), ayahSegment(2, 40));
    player.reach(recitationPlan(boundaries: false), surahSegment(3));

    expect(follow.recited, isNull);
  });

  test('a reader opened during a basmala offers the way to the first ayah', () {
    final plan = recitationPlan();
    player.reach(plan, basmalaSegment(3));
    final late = RecitationFollow(player);
    addTearDown(late.dispose);
    expect(late.following, isFalse);

    player.reach(plan, ayahSegment(3, 1), index: 1);
    expect(late.showReturn, isTrue);
  });

  test('a reader opened during a recitation offers the way to it', () {
    player.reach(recitationPlan(), ayahSegment(2, 5));
    final late = RecitationFollow(player);
    addTearDown(late.dispose);

    expect(late.recited, ayahAt(2, 5));
    expect(late.following, isFalse);
    expect(late.showReturn, isTrue);
    expect(late.request, isNull);

    late.resume();
    expect(late.request!.address, ayahAt(2, 5));
  });

  test('stand mode follows whatever the user does', () {
    final plan = recitationPlan();
    player.reach(plan, ayahSegment(2, 5));
    follow.stand = true;

    expect(follow.request!.address, ayahAt(2, 5));
    follow.userScrolled();

    expect(follow.following, isTrue);
    expect(follow.showReturn, isFalse);
    player.reach(plan, ayahSegment(2, 6), index: 1);
    expect(follow.request!.address, ayahAt(2, 6));

    follow.stand = false;
    follow.userScrolled();
    expect(follow.showReturn, isTrue);
  });

  test('it stops listening to the player once disposed', () {
    final alone = RecitationFollow(player)..dispose();
    player.reach(recitationPlan(), ayahSegment(2, 5));

    expect(alone.recited, isNull);
  });
}
