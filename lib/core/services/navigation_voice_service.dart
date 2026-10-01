import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service responsible for real-time turn-by-turn voice prompts (Waze / Google Maps style)
class NavigationVoiceService {
  factory NavigationVoiceService() => _instance;
  NavigationVoiceService._internal();
  static final NavigationVoiceService _instance = NavigationVoiceService._internal();

  FlutterTts? _tts;
  bool _isInitialized = false;
  bool _isMuted = false;

  bool get isMuted => _isMuted;

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stop();
    }
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted) {
      stop();
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _tts = FlutterTts();

      // Configure default speech rate, pitch, and volume
      await _tts?.setSpeechRate(0.48); // Slightly slower for clear driving instructions
      await _tts?.setVolume(1.0);
      await _tts?.setPitch(1.0);

      // Try setting English first as fallback for driving instructions
      try {
        await _tts?.setLanguage('en-US');
      } catch (_) {}

      _isInitialized = true;
      debugPrint('[NavigationVoice] TTS initialized successfully');
    } catch (e) {
      debugPrint('[NavigationVoice] Failed to initialize TTS: $e');
    }
  }

  /// Speak a turn-by-turn navigation voice guidance message
  Future<void> speak(String message) async {
    if (_isMuted) return;
    if (message.trim().isEmpty) return;

    try {
      if (!_isInitialized) {
        await init();
      }
      // Stop any ongoing speech before issuing new instruction
      await _tts?.stop();
      await _tts?.speak(message);
      debugPrint('[NavigationVoice] Speaking: "$message"');
    } catch (e) {
      debugPrint('[NavigationVoice] Error speaking voice prompt: $e');
    }
  }

  /// Stop any currently speaking voice prompt
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  /// Helper to generate natural spoken text from maneuver type, modifier, street, and distance
  static String formatSpokenInstruction({
    required String maneuverType,
    required String? modifier,
    required String streetName,
    required int distanceMeters,
    bool isImmediate = false,
  }) {
    final street = streetName.trim().isNotEmpty && streetName.trim().toLowerCase() != 'road'
        ? 'onto $streetName'
        : '';

    final cleanType = maneuverType.toLowerCase();
    final cleanMod = modifier?.toLowerCase() ?? '';

    if (cleanType == 'arrive') {
      return 'You have arrived at the customer delivery destination.';
    }

    if (cleanType == 'depart') {
      return isImmediate
          ? 'Head forward $street.'
          : 'In $distanceMeters meters, head forward $street.';
    }

    String direction = 'continue';
    if (cleanMod.contains('sharp left')) {
      direction = 'turn sharp left';
    } else if (cleanMod.contains('sharp right')) {
      direction = 'turn sharp right';
    } else if (cleanMod.contains('slight left')) {
      direction = 'bear slight left';
    } else if (cleanMod.contains('slight right')) {
      direction = 'bear slight right';
    } else if (cleanMod.contains('left')) {
      direction = 'turn left';
    } else if (cleanMod.contains('right')) {
      direction = 'turn right';
    } else if (cleanMod.contains('uturn')) {
      direction = 'make a U-turn';
    } else if (cleanType == 'roundabout') {
      direction = 'enter the roundabout';
    }

    if (isImmediate) {
      return '$direction $street now.'.trim();
    }

    if (distanceMeters <= 50) {
      return '$direction $street.'.trim();
    }

    return 'In $distanceMeters meters, $direction $street.'.trim();
  }
}
