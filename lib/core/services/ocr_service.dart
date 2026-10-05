import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'web_ocr_stub.dart' if (dart.library.js_util) 'web_ocr_impl.dart';

/// Represents a single piece of text extracted by OCR, including metadata
/// for sorting by font size/prominence.
class OcrTextItem {
  const OcrTextItem({
    required this.text,
    this.boundingBoxHeight = 0.0,
  });

  final String text;
  final double boundingBoxHeight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcrTextItem &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;
}

/// Abstract OCR service interface allowing unit testing and mock implementations.
abstract class OcrService {
  Future<List<OcrTextItem>> processImage(String imagePath, {bool filterJunk = true});
  Future<List<OcrTextItem>> processRawImage(String imagePath);
  Future<List<OcrTextItem>> processImageWebOrMobile({
    String? imagePath,
    required Uint8List bytes,
    bool filterJunk = false,
  });

  /// Filters out noisy packaging text (net weights, dates, pure digits)
  /// and sorts by bounding box height (largest text first).
  List<OcrTextItem> filterAndSort(List<OcrTextItem> items);

  /// Merges selected text strings with normalized spacing.
  String mergeTexts(List<String> texts);

  /// Cleans and normalizes raw text string.
  String cleanText(String text);

  /// Returns true if the given line is junk (e.g. weight, date, barcode number).
  bool isJunkText(String text);
}

/// Default implementation using Google ML Kit Text Recognition on Native & Web OCR on Web.
class MlKitOcrService implements OcrService {
  MlKitOcrService({TextRecognizer? recognizer})
      : _recognizer = !kIsWeb
            ? (recognizer ?? TextRecognizer(script: TextRecognitionScript.latin))
            : null;

  final TextRecognizer? _recognizer;

  @override
  Future<List<OcrTextItem>> processRawImage(String imagePath) async {
    return processImage(imagePath, filterJunk: false);
  }

  @override
  Future<List<OcrTextItem>> processImageWebOrMobile({
    String? imagePath,
    required Uint8List bytes,
    bool filterJunk = false,
  }) async {
    if (kIsWeb) {
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final text = await runWebOcr(base64Image);
      if (text.trim().isEmpty) return [];

      final lines = text.split('\n');
      final items = <OcrTextItem>[];
      for (final line in lines) {
        final cleaned = cleanText(line);
        if (cleaned.isNotEmpty) {
          items.add(OcrTextItem(text: cleaned, boundingBoxHeight: 20.0));
        }
      }
      return filterJunk ? filterAndSort(items) : items;
    } else {
      if (imagePath != null && imagePath.isNotEmpty) {
        return processImage(imagePath, filterJunk: filterJunk);
      }
      return [];
    }
  }

  @override
  Future<List<OcrTextItem>> processImage(String imagePath, {bool filterJunk = true}) async {
    if (kIsWeb || _recognizer == null) {
      return [];
    }
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await _recognizer.processImage(inputImage);

      final List<OcrTextItem> items = [];

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final cleaned = cleanText(line.text);
          if (cleaned.isNotEmpty) {
            final box = line.boundingBox;
            final height = box.height;
            items.add(OcrTextItem(
              text: cleaned,
              boundingBoxHeight: height,
            ));
          }
        }
      }

      if (!filterJunk) {
        return items;
      }

      return filterAndSort(items);
    } catch (e) {
      debugPrint('[MLKit processImage Exception]: $e');
      return [];
    }
  }

  @override
  List<OcrTextItem> filterAndSort(List<OcrTextItem> items) {
    final Map<String, OcrTextItem> uniqueMap = {};

    for (final item in items) {
      if (isJunkText(item.text)) continue;

      // Keep item with larger bounding box if duplicate text exists
      if (!uniqueMap.containsKey(item.text) ||
          (uniqueMap[item.text]!.boundingBoxHeight < item.boundingBoxHeight)) {
        uniqueMap[item.text] = item;
      }
    }

    final sorted = uniqueMap.values.toList()
      ..sort((a, b) => b.boundingBoxHeight.compareTo(a.boundingBoxHeight));

    return sorted;
  }

  @override
  String cleanText(String text) {
    // Replace newlines, tabs, and multiple spaces
    final textWithoutBreaks = text.replaceAll(RegExp(r'[\r\n\t]'), ' ');
    final normalized = textWithoutBreaks.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  @override
  bool isJunkText(String text) {
    final cleaned = cleanText(text);

    // 1. Too short (<= 2 characters)
    if (cleaned.length <= 2) return true;

    // 2. Pure digits (e.g. barcode numbers, prices without currency)
    if (RegExp(r'^\d+$').hasMatch(cleaned)) return true;

    // 3. Net weight / volume patterns (e.g., 250g, 500ml, 1.5L, 100g, 12 oz, 55 g, 1kg)
    final weightOrVolumePattern = RegExp(
      r'^\b\d+(\.\d+)?\s*(g|gr|gram|grams|ml|l|liter|liters|kg|oz|fl\s*oz|pack|pcs|sachet)\b$',
      caseSensitive: false,
    );
    if (weightOrVolumePattern.hasMatch(cleaned)) return true;

    // 4. Dates & Manufacturing / Expiry prefixes (e.g. EXP 12/26, MFG 2025-01-01, 12/05/2026)
    final datePattern = RegExp(
      r'(\b(exp|mfg|bb|best\s*before|use\s*by|date)\b|\b\d{1,2}[/\.-]\d{1,2}[/\.-]\d{2,4}\b|\b\d{4}[/\.-]\d{1,2}[/\.-]\d{1,2}\b)',
      caseSensitive: false,
    );
    if (datePattern.hasMatch(cleaned)) return true;

    // 5. Common packaging noise headers
    final junkHeaders = [
      'NUTRITION FACTS',
      'INGREDIENTS',
      'NET WT',
      'NET WEIGHT',
      'NET CONTENT',
      'KEEP REFRIGERATED',
      'STORE IN A COOL',
      'MADE IN',
      'PRODUCT OF',
      'BARCODE',
      'PRICE',
    ];

    final upper = cleaned.toUpperCase();
    for (final header in junkHeaders) {
      if (upper == header || upper.startsWith('$header:')) {
        return true;
      }
    }

    return false;
  }

  @override
  String mergeTexts(List<String> texts) {
    final cleanedList = texts
        .map(cleanText)
        .where((t) => t.isNotEmpty)
        .toList();
    return cleanedList.join(' ');
  }

  void dispose() {
    if (!kIsWeb && _recognizer != null) {
      try {
        _recognizer.close();
      } catch (e) {
        debugPrint('[MLKit Dispose Notice]: $e');
      }
    }
  }
}
