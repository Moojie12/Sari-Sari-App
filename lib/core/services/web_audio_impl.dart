import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Invokes window.playPosOrderChime() synthesized in web/index.html
Future<bool> playWebAudioChime() async {
  if (!kIsWeb) return false;
  try {
    if (globalContext.has('playPosOrderChime')) {
      final res = globalContext.callMethod<JSBoolean?>('playPosOrderChime'.toJS);
      return res?.toDart ?? false;
    }
  } catch (e) {
    debugPrint('[Web Audio Chime Exception]: $e');
  }
  return false;
}
