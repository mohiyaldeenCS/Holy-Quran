import 'package:holyquran/domain/models/reading_theme.dart';

/// A start step threw [cause]. [theme] is the user's when the settings were
/// read before that step, and null when they were not.
final class StartFailure implements Exception {
  const StartFailure(this.cause, {this.theme});

  final Object cause;
  final ThemePreference? theme;

  @override
  String toString() => 'StartFailure: $cause';
}
