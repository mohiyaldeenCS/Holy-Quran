import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Where the app goes instead of [state]'s location on its way in: the
/// first-run setup (O-17) and opening at the last position. Null keeps the
/// location.
FutureOr<String?> startupRedirect(BuildContext context, GoRouterState state) =>
    null;
