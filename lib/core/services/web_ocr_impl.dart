import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:js_util' as js_util;

Future<String> runWebOcr(String base64Image) async {
  if (!kIsWeb) return '';
  try {
    if (js_util.hasProperty(js_util.globalThis, 'performWebOcr')) {
      final promise = js_util.callMethod(js_util.globalThis, 'performWebOcr', [base64Image]);
      final result = await js_util.promiseToFuture(promise);
      return result?.toString() ?? '';
    }
  } catch (e) {
    debugPrint('[Web OCR Exception]: $e');
  }
  return '';
}
