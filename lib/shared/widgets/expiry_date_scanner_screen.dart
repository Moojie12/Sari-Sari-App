import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sari_sari/core/services/ocr_service.dart';
import 'package:sari_sari/core/theme/app_colors.dart';
import '../utils/camera_permission_helper.dart';
import '../utils/expiry_date_parser.dart';

/// Full-screen OCR camera scanner specifically engineered for reading printed
/// expiration dates on product packaging (e.g. cans, boxes, wrappers).
class ExpiryDateScannerScreen extends StatefulWidget {
  const ExpiryDateScannerScreen({super.key});

  @override
  State<ExpiryDateScannerScreen> createState() => _ExpiryDateScannerScreenState();
}

class _ExpiryDateScannerScreenState extends State<ExpiryDateScannerScreen>
    with WidgetsBindingObserver {
  final OcrService _ocrService = MlKitOcrService();
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    final ocr = _ocrService;
    if (ocr is MlKitOcrService) {
      ocr.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final hasPermission =
        await CameraPermissionHelper.ensureCameraPermission(context);
    if (!hasPermission) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Camera permission is required to scan expiration dates.';
        });
      }
      return;
    }

    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _errorMessage = 'No camera hardware found on this device.';
          });
        }
        return;
      }

      final backCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isInitializing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Live camera stream is unavailable.\n\n'
              'You can use "Take Photo with System Camera" below.';
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      if (_isFlashOn) {
        await controller.setFlashMode(FlashMode.off);
      } else {
        await controller.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (_) {}
  }

  Future<void> _captureAndScan() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _isProcessing) {
      return;
    }

    try {
      setState(() => _isProcessing = true);
      final XFile photo = await controller.takePicture();
      await _processPhoto(photo.path);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take photo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: source, imageQuality: 95);
      if (photo == null || !mounted) return;

      setState(() => _isProcessing = true);
      await _processPhoto(photo.path);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _processPhoto(String imagePath) async {
    try {
      final items = await _ocrService.processRawImage(imagePath);
      final lines = items.map((i) => i.text).toList();
      final candidates = ExpiryDateParser.parseLines(lines);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      await _showResultDialog(File(imagePath), candidates, lines);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showResultDialog(
    File imageFile,
    List<ExpiryDateCandidate> candidates,
    List<String> rawLines,
  ) async {
    DateTime? selectedDate = candidates.isNotEmpty ? candidates.first.date : null;

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_month, color: AppColors.primaryOrange, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Expiration Date Result',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.darkText),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.secondaryText),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    if (selectedDate != null) ...[
                      // Highlighted Detected Date Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade600, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                const SizedBox(width: 6),
                                const Text(
                                  'Detected Expiration Date:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () async {
                                    final now = DateTime.now();
                                    final initial = selectedDate ?? now;
                                    final d = await showDatePicker(
                                      context: modalCtx,
                                      initialDate: initial,
                                      firstDate: DateTime(now.year - 2),
                                      lastDate: DateTime(now.year + 15),
                                    );
                                    if (d != null) {
                                      setModalState(() => selectedDate = d);
                                    }
                                  },
                                  child: const Text(
                                    'Edit Date',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatFullDate(selectedDate!),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                              ),
                            ),
                            if (candidates.isNotEmpty && candidates.first.contextSnippet.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'From text: "${candidates.first.contextSnippet}"',
                                style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // If multiple date candidates found, show selectable chips
                      if (candidates.length > 1) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Other detected dates on package:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.labelText),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: candidates.map((c) {
                            final isSel = selectedDate == c.date;
                            return ChoiceChip(
                              label: Text(_formatDateShort(c.date)),
                              selected: isSel,
                              selectedColor: AppColors.primaryOrange,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : AppColors.darkText,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedDate = c.date);
                              },
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 18),
                      // Confirm button
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text(
                            'Use this Expiration Date',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx, _formatIso(selectedDate!));
                          },
                        ),
                      ),
                    ] else ...[
                      // No Date Found Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.amber, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'No Expiration Date Detected',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Text(
                              'The camera couldn\'t clearly find a date like "EXP: DD/MM/YY" or "BB MM/YY". Try moving closer with good lighting, or pick the date manually.',
                              style: TextStyle(fontSize: 12, color: AppColors.darkText),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryOrange,
                                side: const BorderSide(color: AppColors.primaryOrange),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Try Again'),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.edit_calendar, color: Colors.white, size: 18),
                              label: const Text(
                                'Pick Manually',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                final now = DateTime.now();
                                final d = await showDatePicker(
                                  context: modalCtx,
                                  initialDate: now,
                                  firstDate: DateTime(now.year - 2),
                                  lastDate: DateTime(now.year + 15),
                                );
                                if (d != null && modalCtx.mounted) {
                                  Navigator.pop(ctx, _formatIso(d));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null && mounted) {
      Navigator.pop(context, picked);
    }
  }

  Future<void> _pickDateManually() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 15),
    );
    if (d != null && mounted) {
      Navigator.pop(context, _formatIso(d));
    }
  }

  String _formatFullDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatDateShort(DateTime d) {
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatIso(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cutOutWidth = size.width * 0.78;
    final cutOutHeight = cutOutWidth * 0.58;
    final cutOutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 40),
      width: cutOutWidth,
      height: cutOutHeight,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          if (_cameraController != null && _cameraController!.value.isInitialized)
            CameraPreview(_cameraController!)
          else if (_isInitializing)
            const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
          else
            _buildErrorView(),

          // 2. Cut-out Overlay
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ExpiryOverlayPainter(cutOutRect: cutOutRect),
            ),
          ),

          // 3. Instruction Banner under cut-out
          Positioned(
            left: 20,
            right: 20,
            top: cutOutRect.bottom + 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(150),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.crop_free, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Position the printed expiration date inside frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Header (Back button, Title, Flash)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black.withAlpha(120),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(120),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Scan Expiration Date',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      backgroundColor: Colors.black.withAlpha(120),
                      child: IconButton(
                        icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                        onPressed: _toggleFlash,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Bottom Controls (Gallery, Shutter Button, Manual Picker)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withAlpha(50),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.photo_library),
                          onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                        ),
                        const SizedBox(height: 4),
                        const Text('Gallery', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),

                    // Shutter button
                    GestureDetector(
                      onTap: _isProcessing ? null : _captureAndScan,
                      child: Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryOrange,
                          ),
                          child: _isProcessing
                              ? const Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                  ),
                                )
                              : const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                        ),
                      ),
                    ),

                    // Manual Picker
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withAlpha(50),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.edit_calendar),
                          onPressed: _isProcessing ? null : _pickDateManually,
                        ),
                        const SizedBox(height: 4),
                        const Text('Manual', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 54),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Camera unavailable',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
              icon: const Icon(Icons.camera, color: Colors.white),
              label: const Text('Take Photo with System Camera', style: TextStyle(color: Colors.white)),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              icon: const Icon(Icons.calendar_today, size: 16),
              label: const Text('Pick Date Manually'),
              onPressed: _pickDateManually,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryOverlayPainter extends CustomPainter {
  final Rect cutOutRect;

  _ExpiryOverlayPainter({required this.cutOutRect});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutOutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(cutOutRect, const Radius.circular(16)));

    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, cutOutPath);

    final dimPaint = Paint()..color = Colors.black.withAlpha(160);
    canvas.drawPath(overlayPath, dimPaint);

    final borderPaint = Paint()
      ..color = AppColors.primaryOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(RRect.fromRectAndRadius(cutOutRect, const Radius.circular(16)), borderPaint);

    // Corner guides
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 22.0;

    // Top-Left
    canvas.drawLine(cutOutRect.topLeft, cutOutRect.topLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(cutOutRect.topLeft, cutOutRect.topLeft + const Offset(0, cornerLength), cornerPaint);

    // Top-Right
    canvas.drawLine(cutOutRect.topRight, cutOutRect.topRight - const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(cutOutRect.topRight, cutOutRect.topRight + const Offset(0, cornerLength), cornerPaint);

    // Bottom-Left
    canvas.drawLine(cutOutRect.bottomLeft, cutOutRect.bottomLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(cutOutRect.bottomLeft, cutOutRect.bottomLeft - const Offset(0, cornerLength), cornerPaint);

    // Bottom-Right
    canvas.drawLine(cutOutRect.bottomRight, cutOutRect.bottomRight - const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(cutOutRect.bottomRight, cutOutRect.bottomRight - const Offset(0, cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
