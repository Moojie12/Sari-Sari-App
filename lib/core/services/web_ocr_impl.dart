import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Future<String> runWebOcr(String base64Image) async {
  if (!kIsWeb) return '';
  try {
    if (globalContext.has('performWebOcr')) {
      final jsResult = globalContext.callMethod<JSString?>('performWebOcr'.toJS, base64Image.toJS);
      return jsResult?.toDart ?? '';
    }
  } catch (e) {
    debugPrint('[Web OCR Exception]: $e');
  }
  return '';
}
