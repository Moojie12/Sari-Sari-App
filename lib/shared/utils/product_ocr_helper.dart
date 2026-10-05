import 'package:flutter/material.dart';

import 'package:sari_sari/core/services/ocr_service.dart';
import '../widgets/ocr_camera_scanner_screen.dart';

/// Opens the Live Camera Product Name Scanner screen to scan product packaging text.
/// Returns the selected/edited product name string, or `null` if canceled.
Future<String?> scanProductNameWithOcr(
  BuildContext context, {
  OcrService? ocrService,
}) async {
  final result = await Navigator.push<String?>(
    context,
    MaterialPageRoute(
      builder: (context) => OcrCameraScannerScreen(
        ocrService: ocrService,
      ),
    ),
  );
  return result;
}
