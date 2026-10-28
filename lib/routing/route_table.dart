import 'package:go_router/go_router.dart';

/// Whether [router] has a screen at [location]. An entry for a screen not
/// built yet is not shown, as PRD §7.1 rules for the home doors.
bool hasRoute(GoRouter router, String location) =>
    !router.configuration.findMatch(Uri.parse(location)).isError;
