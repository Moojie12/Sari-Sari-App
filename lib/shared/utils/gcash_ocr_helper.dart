import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sari_sari/core/services/ocr_service.dart';

class GcashReceiptValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? extractedRefNumber;

  const GcashReceiptValidationResult({
    required this.isValid,
    this.errorMessage,
    this.extractedRefNumber,
  });
}

/// Helper utility for parsing and validating GCash receipts & QR codes via OCR & Barcode Scanning.
class GcashOcrHelper {
  GcashOcrHelper._();

  /// Maximum allowed file size for receipt screenshots: 5MB in bytes
  static const int maxFileSizeBytes = 5 * 1024 * 1024;

  /// Validates whether an uploaded image file is a genuine GCash QR Code.
  /// Combines 2D Barcode/QR matrix scanning with OCR text recognition.
  static Future<GcashReceiptValidationResult> validateGcashQrImage({
    required String imagePath,
    required Uint8List bytes,
  }) async {
    // 1. File Size Validation (5MB Limit)
    if (bytes.length > maxFileSizeBytes) {
      final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      return GcashReceiptValidationResult(
        isValid: false,
        errorMessage: 'Image size ($mb MB) exceeds 5MB limit. Please upload a smaller screenshot.',
      );
    }

    // 2. QR Code Barcode Matrix Detection & OCR on Non-Web Platforms
    bool hasQrCodeMatrix = false;
    String? qrPayload;
    List<OcrTextItem> ocrItems = [];

    if (!kIsWeb) {
      try {
        final controller = MobileScannerController();
        final BarcodeCapture? capture = await controller.analyzeImage(imagePath);
        await controller.dispose();

        if (capture != null && capture.barcodes.isNotEmpty) {
          for (final barcode in capture.barcodes) {
            if (barcode.format == BarcodeFormat.qrCode || barcode.type == BarcodeType.text) {
              hasQrCodeMatrix = true;
              qrPayload = barcode.rawValue ?? barcode.displayValue;
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('[MobileScanner analyzeImage error]: $e');
      }

      try {
        final ocrService = MlKitOcrService();
        ocrItems = await ocrService.processImage(imagePath);
        ocrService.dispose();
      } catch (e) {
        debugPrint('[OCR Service error]: $e');
      }
    }

    final combinedText = (ocrItems.map((i) => i.text.toLowerCase()).join(' ') + ' ' + (qrPayload?.toLowerCase() ?? '')).trim();

    // Must have a QR code matrix OR OCR text
    if (!hasQrCodeMatrix && combinedText.isEmpty) {
      return const GcashReceiptValidationResult(
        isValid: false,
        errorMessage: 'Invalid Image: No GCash QR Code detected. Please upload an official GCash QR Code screenshot or standee.',
      );
    }

    // 4. Verify GCash Signature Terms
    final gcashTerms = [
      'gcash',
      'g-cash',
      'instapay',
      'transfer',
      'fee',
      'mobile',
      '+63',
      'user id',
      '000201', // EMVCo QR code payload prefix for GCash/InstaPay
      'ph.com.gcash',
      'merchant'
    ];

    bool hasGcashTerm = gcashTerms.any((term) => combinedText.contains(term));
    bool hasMaskedName = RegExp(r'[a-z]{1,4}\*[a-z0-9\*]*', caseSensitive: false).hasMatch(combinedText);
    bool hasPhonePattern = RegExp(r'(\+?63|09)\s*\d{2,4}').hasMatch(combinedText);

    bool isValidGcashQr = (hasQrCodeMatrix && (hasGcashTerm || hasMaskedName || hasPhonePattern || combinedText.isEmpty)) ||
        (hasGcashTerm && (hasMaskedName || hasPhonePattern || hasQrCodeMatrix));

    if (!isValidGcashQr) {
      return const GcashReceiptValidationResult(
        isValid: false,
        errorMessage: 'Invalid Image: Only official GCash QR Codes are allowed. Please upload a valid GCash QR standee or screenshot.',
      );
    }

    return const GcashReceiptValidationResult(isValid: true);
  }

  /// Validates whether the given OCR text items and file size represent an authentic GCash receipt.
  static GcashReceiptValidationResult validateReceipt({
    required List<OcrTextItem> items,
    required int fileSizeBytes,
  }) {
    // 1. File Size Validation (5MB Limit)
    if (fileSizeBytes > maxFileSizeBytes) {
      final mb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      return GcashReceiptValidationResult(
        isValid: false,
        errorMessage: 'The screenshot file size ($mb MB) is too large. Please upload a screenshot under 5MB.',
      );
    }

    if (items.isEmpty) {
      if (kIsWeb) {
        return const GcashReceiptValidationResult(isValid: true);
      }
      return const GcashReceiptValidationResult(
        isValid: false,
        errorMessage: 'The picture is too blurry or dark to read. Please upload a clear, bright screenshot of your GCash receipt.',
      );
    }

    final combinedText = items.map((i) => i.text.toLowerCase()).join(' ');

    // 2. Signature GCash Receipt Keywords
    final primaryKeywords = [
      'gcash',
      'express send',
      'send money',
      'pay qr',
      'g-cash',
      'gcash send',
      'transfer',
      'amount',
      'sent',
      'total amount',
      'ref',
      'reference',
      'instapay',
      'pesonet',
      'transaction',
      'received',
      'paid',
      'payment',
      'successfully',
      'receipt'
    ];

    final secondaryKeywords = [
      'ref',
      'reference',
      'successfully',
      'sent',
      'amount',
      'paid',
      'payment',
      'total amount',
      'php',
      'balance',
      'no.',
      'num',
      'date',
      'time',
      'fee',
      'account'
    ];

    bool hasPrimary = primaryKeywords.any((kw) => combinedText.contains(kw));
    int secondaryCount = secondaryKeywords.where((kw) => combinedText.contains(kw)).length;

    final extractedRef = extractRefNumber(items);

    // Validation rule: Must have at least 1 primary term OR (reference number + at least 1 secondary term) OR secondaryCount >= 1
    bool isGcashReceipt = hasPrimary || extractedRef != null || secondaryCount >= 1;

    if (!isGcashReceipt) {
      return const GcashReceiptValidationResult(
        isValid: false,
        errorMessage: 'The uploaded picture does not look like a GCash receipt or is too blurry. Please make sure the GCash Ref No. and details are clearly visible.',
      );
    }

    return GcashReceiptValidationResult(
      isValid: true,
      extractedRefNumber: extractedRef,
    );
  }

  /// Validates whether the given OCR text items represent an authentic GCash QR Code standee or screenshot.
  static GcashReceiptValidationResult validateGcashQrCode(List<OcrTextItem> items) {
    if (items.isEmpty) {
      return const GcashReceiptValidationResult(
        isValid: false,
        errorMessage: 'Invalid Image: No GCash details detected. Please upload an official GCash QR Code screenshot or standee.',
      );
    }

    final combinedText = items.map((i) => i.text.toLowerCase()).join(' ');

    // Must contain GCash specific terms or InstaPay + Mobile/User ID format
    bool hasGcash = combinedText.contains('gcash') || combinedText.contains('g-cash');
    bool hasInstapay = combinedText.contains('instapay');
    bool hasTransferFees = combinedText.contains('transfer fee') || combinedText.contains('transfer fees');
    bool hasUserId = combinedText.contains('user id') || combinedText.contains('22w');
    bool hasMobileNo = combinedText.contains('mobile no') || combinedText.contains('+63');
    bool hasMaskedName = RegExp(r'[a-z]{1,4}\*[a-z0-9\*]*', caseSensitive: false).hasMatch(combinedText);

    // Strict validation: Must contain 'gcash' OR ('instapay' + transfer fees / user id / mobile no / masked name)
    bool isGcashQr = hasGcash || (hasInstapay && (hasTransferFees || hasUserId || hasMobileNo || hasMaskedName));

    if (!isGcashQr) {
      return const GcashReceiptValidationResult(
        isValid: false,
        errorMessage: 'Invalid Image: Only official GCash QR Codes are allowed. Please upload a valid GCash QR standee or screenshot.',
      );
    }

    return const GcashReceiptValidationResult(isValid: true);
  }

  /// Extracts a GCash reference number from a list of OCR items or raw text.
  /// GCash reference numbers are typically 10 to 13 digits long and often
  /// preceded by "Ref No", "Reference No", "Ref", or "Ref.", e.g., "Ref No. 5045 062 915234".
  static String? extractRefNumber(List<OcrTextItem> items) {
    if (items.isEmpty) return null;

    // 1. First pass: look for lines containing explicit "Ref" or "Reference" keywords
    final refKeywordRegex = RegExp(
      r'(?:ref|reference|ref\s*no|ref\s*num|ref\.)[:\s\.-]*([0-9\s-]{9,20})',
      caseSensitive: false,
    );

    for (final item in items) {
      final match = refKeywordRegex.firstMatch(item.text);
      if (match != null && match.group(1) != null) {
        final cleanDigits = match.group(1)!.replaceAll(RegExp(r'\D'), '');
        if (cleanDigits.length >= 9 && cleanDigits.length <= 15) {
          return cleanDigits;
        }
      }
    }

    // 2. Second pass: Join all text and search across multiline patterns
    final combinedText = items.map((i) => i.text).join(' ');
    final match = refKeywordRegex.firstMatch(combinedText);
    if (match != null && match.group(1) != null) {
      final cleanDigits = match.group(1)!.replaceAll(RegExp(r'\D'), '');
      if (cleanDigits.length >= 9 && cleanDigits.length <= 15) {
        return cleanDigits;
      }
    }

    // 3. Third pass: Look for grouped numbers like "5045 062 915234" or "1002 345 6789"
    final groupedDigitsRegex = RegExp(r'\b\d{3,4}[\s-]\d{3,4}[\s-]\d{3,6}\b');
    final groupedMatch = groupedDigitsRegex.firstMatch(combinedText);
    if (groupedMatch != null) {
      final cleanDigits = groupedMatch.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (cleanDigits.length >= 9 && cleanDigits.length <= 15) {
        return cleanDigits;
      }
    }

    // 4. Fourth pass: Look for standalone digit sequences of 10-13 digits
    final standaloneDigitsRegex = RegExp(r'\b\d{10,13}\b');
    final standaloneMatch = standaloneDigitsRegex.firstMatch(combinedText);
    if (standaloneMatch != null) {
      return standaloneMatch.group(0);
    }

    return null;
  }

  /// Normalizes a GCash reference number for clean display (e.g. "1002 345 6789").
  static String formatRefNumber(String rawRef) {
    final digits = rawRef.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
    }
    if (digits.length == 11) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7)}';
    }
    return digits;
  }
}
