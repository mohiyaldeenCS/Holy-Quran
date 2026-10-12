import 'dart:math';

final Random _random = Random.secure();

/// A random 128-bit id as 32 lower-case hexadecimal digits: unique across
/// devices without coordination, so synced rows can be merged (PRD §10.6).
String newId() => [
  for (var i = 0; i < 16; i++)
    _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();
