import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'web_audio_stub.dart' if (dart.library.js_interop) 'web_audio_impl.dart';

/// Sound and haptic service for POS and Admin real-time alerts.
class PosAudioService {
  PosAudioService._();

  /// Plays a distinctive POS order chime and triggers haptics on mobile devices.
  static Future<void> playOrderChime() async {
    try {
      if (kIsWeb) {
        final played = await playWebAudioChime();
        if (!played) {
          await SystemSound.play(SystemSoundType.alert);
        }
      } else {
        await SystemSound.play(SystemSoundType.alert);
        await HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('[PosAudioService] Error playing chime: $e');
    }
  }

  /// Plays a standard notification alert tone
  static Future<void> playAlertSound() async {
    try {
      if (kIsWeb) {
        final played = await playWebAudioChime();
        if (!played) {
          await SystemSound.play(SystemSoundType.alert);
        }
      } else {
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {}
  }
}
