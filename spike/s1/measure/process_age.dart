import 'dart:ffi';
import 'dart:io';

/// How long this process has run, on Android: the time since boot from
/// `/proc/uptime` less the process start time, field 22 of
/// `/proc/self/stat`, in clock ticks. Null on other platforms or when
/// either file cannot be read or parsed. Its resolution is one clock tick
/// (10 ms at 100 Hz) and 10 ms of uptime. An app process is forked from the
/// zygote, so this counts from the fork, before any app code runs.
Duration? processAge() {
  if (!Platform.isAndroid) return null;
  try {
    return processAgeFrom(
      stat: File('/proc/self/stat').readAsStringSync(),
      uptime: File('/proc/uptime').readAsStringSync(),
      ticksPerSecond: clockTicksPerSecond(),
    );
  } on FileSystemException {
    return null;
  }
}

/// The age of the process described by [stat], the contents of
/// `/proc/<pid>/stat`, at the time of [uptime], the contents of
/// `/proc/uptime`; null when either does not parse.
Duration? processAgeFrom({
  required String stat,
  required String uptime,
  required int ticksPerSecond,
}) {
  final start = processStartTicks(stat);
  final since = _uptimeMicroseconds(uptime);
  if (start == null || since == null || ticksPerSecond <= 0) return null;
  final age = since - start * Duration.microsecondsPerSecond ~/ ticksPerSecond;
  return age < 0 ? null : Duration(microseconds: age);
}

/// Field 22 of a `/proc/<pid>/stat` line, the start time in clock ticks
/// after boot. Field 2, the command name, is in parentheses and may hold
/// spaces and parentheses itself, so the fields are counted from the last
/// `)`.
int? processStartTicks(String stat) {
  final close = stat.lastIndexOf(')');
  if (close < 0) return null;
  final fields = stat
      .substring(close + 1)
      .trim()
      .split(' ')
      .where((f) => f.isNotEmpty)
      .toList();
  // fields[0] is field 3, the state.
  const index = 22 - 3;
  return fields.length > index ? int.tryParse(fields[index]) : null;
}

int? _uptimeMicroseconds(String uptime) {
  final match = RegExp(r'^\s*(\d+)\.(\d{1,6})\s').firstMatch(uptime);
  if (match == null) return null;
  final fraction = match.group(2)!.padRight(6, '0');
  return int.parse(match.group(1)!) * Duration.microsecondsPerSecond +
      int.parse(fraction);
}

/// `sysconf(_SC_CLK_TCK)` from the C library; 100, the USER_HZ of every
/// Linux and Android ABI, when it cannot be called.
int clockTicksPerSecond() {
  const scClkTck = 2;
  try {
    final sysconf = DynamicLibrary.process()
        .lookupFunction<Long Function(Int), int Function(int)>('sysconf');
    final ticks = sysconf(scClkTck);
    return ticks > 0 ? ticks : 100;
  } on Object {
    return 100;
  }
}
