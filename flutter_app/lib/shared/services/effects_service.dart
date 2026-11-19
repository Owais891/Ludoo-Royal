import 'package:vibration/vibration.dart';
import '../../core/storage/app_config.dart';

/// Audio + haptic helper (kept simple - no asset files required to compile).
class EffectsService {
  static Future<void> vibrate({int millis = 30, int amplitude = 128}) async {
    if (!AppConfig.vibrationEnabled) return;
    try {
      final hasVib = await Vibration.hasVibrator() ?? false;
      if (hasVib) {
        await Vibration.vibrate(duration: millis, amplitude: amplitude);
      }
    } catch (_) {}
  }

  static Future<void> diceRollTick() => vibrate(millis: 15);

  static Future<void> tokenMove() => vibrate(millis: 25);

  static Future<void> capture() => vibrate(millis: 80, amplitude: 200);

  static Future<void> win() async {
    if (!AppConfig.vibrationEnabled) return;
    try {
      await Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 200]);
    } catch (_) {}
  }

  static Future<void> error() => vibrate(millis: 100, amplitude: 200);
}
