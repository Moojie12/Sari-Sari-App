import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Invokes window.playPosOrderChime() synthesized in web/index.html
Future<bool> playWebAudioChime() async {
  if (!kIsWeb) return false;
  try {
    if (globalContext.has('playPosOrderChime')) {
      final res = globalContext.callMethod('playPosOrderChime'.toJS);
      if (res != null) {
        if (res is JSBoolean) return res.toDart;
        return true;
      }
    }
  } catch (e) {
    debugPrint('[Web Audio Chime Notice]: $e');
  }
  return false;
}
