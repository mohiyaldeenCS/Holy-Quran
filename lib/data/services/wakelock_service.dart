import 'package:wakelock_plus/wakelock_plus.dart';

/// The platform's screen wakelock.
class WakelockService {
  const WakelockService();

  Future<void> enable() => WakelockPlus.enable();

  Future<void> disable() => WakelockPlus.disable();
}
