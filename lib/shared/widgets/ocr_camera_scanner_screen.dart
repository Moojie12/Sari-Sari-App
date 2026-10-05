import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sari_sari/core/services/ocr_service.dart';
import '../../core/theme/app_colors.dart';
import '../utils/camera_permission_helper.dart';

/// Full-screen camera scanner screen for scanning product packaging text via OCR.
/// Includes automatic fallback to system camera photo capture if live camera hardware
/// stream is unavailable (e.g. on Android Emulators or hardware conflicts).
class OcrCameraScannerScreen extends StatefulWidget {
  const OcrCameraScannerScreen({
    super.key,
    this.ocrService,
  });

  final OcrService? ocrService;

  @override
  State<OcrCameraScannerScreen> createState() => _OcrCameraScannerScreenState();
}

class _OcrCameraScannerScreenState extends State<OcrCameraScannerScreen>
    with WidgetsBindingObserver {
  late final OcrService _ocrService;
  bool _isCustomOcrService = false;

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

    if (widget.ocrService != null) {
      _ocrService = widget.ocrService!;
      _isCustomOcrService = true;
    } else {
      _ocrService = MlKitOcrService();
    }

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    if (!_isCustomOcrService) {
      final service = _ocrService;
      if (service is MlKitOcrService) {
        service.dispose();
      }
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
              'Camera permission is required to scan product packaging.';
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
        ResolutionPreset.medium,
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
              'Live camera stream is unavailable on this device/emulator.\n\n'
              'You can use "Take Photo with Camera" below to scan your packaging.';
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
      setState(() {
        _isProcessing = true;
      });

      final XFile photo = await controller.takePicture();
      final items = await _ocrService.processImage(photo.path);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      await _showResultBottomSheet(File(photo.path), items);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read text: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageAndScan(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (photo == null || !mounted) return;

      setState(() {
        _isProcessing = true;
      });

      final items = await _ocrService.processImage(photo.path);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      await _showResultBottomSheet(File(photo.path), items);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read text: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showResultBottomSheet(
      File imageFile, List<OcrTextItem> items) async {
    final TextEditingController nameController = TextEditingController();
    final Set<String> selectedTexts = {};

    if (items.isNotEmpty) {
      selectedTexts.add(items.first.text);
      nameController.text = items.first.text;
    }

    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void toggleChip(String text) {
              setSheetState(() {
                if (selectedTexts.contains(text)) {
                  selectedTexts.remove(text);
                } else {
                  selectedTexts.add(text);
                }

                final orderedSelected = items
                    .where((item) => selectedTexts.contains(item.text))
                    .map((item) => item.text)
                    .toList();

                nameController.text = _ocrService.mergeTexts(orderedSelected);
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      const Icon(Icons.center_focus_strong,
                          color: AppColors.primaryOrange, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Recognized Product Text',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context, null),
                      ),
                    ],
                  ),
                  const Divider(),

                  // Text Field Input
                  const Text(
                    'Product Name (edit or tap chips below):',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.labelText),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Lucky Me Pancit Canton',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primaryOrange, width: 2),
                      ),
                      suffixIcon: nameController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setSheetState(() {
                                  nameController.clear();
                                  selectedTexts.clear();
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // Detected Chips List
                  if (items.isNotEmpty) ...[
                    const Text(
                      'Detected Text Lines (Tap to add/remove):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: items.map((item) {
                            final isSelected =
                                selectedTexts.contains(item.text);
                            return FilterChip(
                              selected: isSelected,
                              label: Text(
                                item.text,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.darkText,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                              selectedColor: AppColors.primaryOrange,
                              backgroundColor: Colors.grey.shade100,
                              checkmarkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primaryOrange
                                      : Colors.grey.shade300,
                                ),
                              ),
                              onSelected: (_) => toggleChip(item.text),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No clear text recognized. Please frame the product packaging closer and re-scan.',
                        style: TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Confirm Action Button
                  ElevatedButton.icon(
                    onPressed: () {
                      final text = nameController.text.trim();
                      if (text.isNotEmpty) {
                        Navigator.pop(context, text);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Please enter or select a product name.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text(
                      'Confirm Product Name',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cutOutWidth = size.width * 0.85;
    final cutOutHeight = size.height * 0.40;
    final cutOutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 30),
      width: cutOutWidth,
      height: cutOutHeight,
    );

    final bool isCameraReady = _cameraController != null &&
        _cameraController!.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live Camera Preview
          if (isCameraReady)
            CameraPreview(_cameraController!)
          else if (_isInitializing)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            )
          else
            _ErrorView(
              errorMessage: _errorMessage ?? 'Camera not available.',
              onTakePhoto: () => _pickImageAndScan(ImageSource.camera),
              onPickGallery: () => _pickImageAndScan(ImageSource.gallery),
              onRetry: _initializeCamera,
            ),

          // Dark Overlay with Cutout Frame
          if (isCameraReady)
            IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _OcrOverlayPainter(
                  cutOutRect: cutOutRect,
                  cutOutRadius: 18,
                  accentColor: AppColors.primaryOrange,
                ),
              ),
            ),

          // Instructional Text below frame
          if (isCameraReady)
            Positioned(
              left: 24,
              right: 24,
              top: cutOutRect.bottom + 20,
              child: Column(
                children: const [
                  Icon(Icons.center_focus_strong,
                      color: Colors.white, size: 24),
                  SizedBox(height: 8),
                  Text(
                    'Position product packaging inside the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Header Controls (Back button, Title pill, Flash toggle)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context, null),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'Scan Product Packaging',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isCameraReady)
                      _RoundIconButton(
                        icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        iconColor: _isFlashOn ? Colors.amber : Colors.white,
                        onTap: _toggleFlash,
                      )
                    else
                      const SizedBox(width: 42),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Shutter Controls
          if (isCameraReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery Fallback Button
                    _RoundIconButton(
                      icon: Icons.photo_library,
                      size: 48,
                      iconSize: 22,
                      onTap: () => _pickImageAndScan(ImageSource.gallery),
                    ),

                    // Main Camera Shutter Button
                    GestureDetector(
                      onTap: _isProcessing ? null : _captureAndScan,
                      child: Container(
                        height: 72,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primaryOrange.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: _isProcessing
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.camera_alt,
                                      color: Colors.white, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    'SCAN TEXT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(width: 48), // Spacer to balance layout
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
    this.size = 42,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.errorMessage,
    required this.onTakePhoto,
    required this.onPickGallery,
    required this.onRetry,
  });

  final String errorMessage;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_enhance_outlined,
                color: AppColors.primaryOrange, size: 52),
            const SizedBox(height: 16),
            const Text(
              'Scan Product Packaging',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Primary Camera Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTakePhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text(
                  'Take Photo with Camera',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary Options
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickGallery,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.photo_library,
                        size: 18, color: Colors.white70),
                    label: const Text('Gallery',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.refresh,
                        size: 18, color: Colors.white70),
                    label: const Text('Retry View',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OcrOverlayPainter extends CustomPainter {
  _OcrOverlayPainter({
    required this.cutOutRect,
    required this.cutOutRadius,
    required this.accentColor,
  });

  final Rect cutOutRect;
  final double cutOutRadius;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath =
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutOutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
          cutOutRect, Radius.circular(cutOutRadius)));

    final scrimPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutOutPath,
    );

    canvas.drawPath(
        scrimPath, Paint()..color = Colors.black.withValues(alpha: 0.55));

    const cornerLength = 26.0;
    const strokeWidth = 3.5;
    final cornerPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    void drawCorner(Offset corner, double dx, double dy) {
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx, corner.dy + dy * cornerLength)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx + dx * cornerLength, corner.dy),
        cornerPaint,
      );
    }

    drawCorner(cutOutRect.topLeft, 1, 1);
    drawCorner(cutOutRect.topRight, -1, 1);
    drawCorner(cutOutRect.bottomLeft, 1, -1);
    drawCorner(cutOutRect.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _OcrOverlayPainter oldDelegate) {
    return oldDelegate.cutOutRect != cutOutRect ||
        oldDelegate.accentColor != accentColor;
  }
}
