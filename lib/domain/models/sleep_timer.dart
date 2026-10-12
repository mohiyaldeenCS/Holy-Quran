/// When playback goes to sleep (`AU-07`): after a number of minutes, with a
/// fade, or at the end of the current ayah or surah.
sealed class SleepTimer {
  const SleepTimer();
}

final class SleepAfter extends SleepTimer {
  SleepAfter(int minutes)
    : minutes = RangeError.checkValueInInterval(
        minutes,
        minMinutes,
        maxMinutes,
        'minutes',
      );

  static const minMinutes = 5;
  static const maxMinutes = 120;

  final int minutes;

  Duration get duration => Duration(minutes: minutes);

  @override
  bool operator ==(Object other) =>
      other is SleepAfter && other.minutes == minutes;

  @override
  int get hashCode => minutes.hashCode;
}

final class SleepAtEndOfAyah extends SleepTimer {
  const SleepAtEndOfAyah();
}

final class SleepAtEndOfSurah extends SleepTimer {
  const SleepAtEndOfSurah();
}
