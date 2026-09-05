import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';

/// What a scan is being used for. Both screens share the exact same
/// theme/layout — only the label, icon, and frame shape change so staff
/// can tell at a glance which kind of scan they're doing.
enum _ScanPurpose { productBarcode, expiryDate }

class _ScanPurposeConfig {
  const _ScanPurposeConfig({
    required this.title,
    required this.instruction,
    required this.icon,
    required this.frameAspectRatio,
  });

  final String title;
  final String instruction;
  final IconData icon;

  /// width / height of the scan cut-out. Barcodes are wide; a printed
  /// expiry date/QR is closer to square.
  final double frameAspectRatio;
}

const _purposeConfig = {
  _ScanPurpose.productBarcode: _ScanPurposeConfig(
    title: 'Scan Product Barcode',
    instruction: 'Center the barcode inside the frame',
    icon: Icons.qr_code_scanner_rounded,
    frameAspectRatio: 1.7,
  ),
  _ScanPurpose.expiryDate: _ScanPurposeConfig(
    title: 'Scan Expiry Date',
    instruction: 'Center the expiry date code inside the frame',
    icon: Icons.event_outlined,
    frameAspectRatio: 1.15,
  ),
};

/// Scanner used to read a product's barcode (Add Product, Stock Receiving,
/// POS).
class BarcodeScannerScreen extends StatelessWidget {
  const BarcodeScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ScannerScreen(purpose: _ScanPurpose.productBarcode);
  }
}

/// Scanner used to read a product's printed expiry-date code (Add Product's
/// batch step). Same visual theme as [BarcodeScannerScreen], distinguished
/// by title, icon, and a squarer frame.
class ExpiryDateScannerScreen extends StatelessWidget {
  const ExpiryDateScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ScannerScreen(purpose: _ScanPurpose.expiryDate);
  }
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen({required this.purpose});

  final _ScanPurpose purpose;

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    torchEnabled: false,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false;

  _ScanPurposeConfig get _config => _purposeConfig[widget.purpose]!;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    _handled = true;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cutOutWidth = size.width * 0.74;
    final cutOutHeight = cutOutWidth / _config.frameAspectRatio;
    final cutOutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 24),
      width: cutOutWidth,
      height: cutOutHeight,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live camera preview, with a themed fallback if the camera
          // can't start (no permission / no hardware) instead of a blank
          // or glitchy surface.
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => _CameraErrorView(error: error),
          ),

          // Dimmed scrim with a clear cut-out over the scan area.
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ScannerOverlayPainter(
                cutOutRect: cutOutRect,
                cutOutRadius: 18,
                accentColor: AppColors.primaryOrange,
              ),
            ),
          ),

          // Purpose icon + instruction, under the frame.
          Positioned(
            left: 24,
            right: 24,
            top: cutOutRect.bottom + 20,
            child: Column(
              children: [
                Icon(_config.icon, color: Colors.white, size: 22),
                const SizedBox(height: 8),
                Text(
                  _config.instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Floating header: back button + title pill + flash toggle.
          // Pinned to the top with Positioned so Stack's StackFit.expand
          // doesn't stretch it to full height and vertically center the
          // Row (which was pushing it down into the scan frame).
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
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          _config.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _controller,
                      builder: (context, state, child) {
                        final isOn = state.torchState == TorchState.on;
                        return _RoundIconButton(
                          icon: isOn ? Icons.flash_on : Icons.flash_off,
                          iconColor: Colors.white,
                          onTap: () => _controller.toggleTorch(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating footer: flip camera.
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: Center(
                child: _RoundIconButton(
                  icon: Icons.cameraswitch_outlined,
                  size: 50,
                  iconSize: 22,
                  onTap: () => _controller.switchCamera(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple round translucent icon button used for the scanner's floating
/// controls. Kept minimal on purpose — a solid dark disc with a white (or
/// orange, when active) icon — so it reads clearly over any camera feed.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
    this.backgroundColor,
    this.size = 42,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final Color? backgroundColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.black.withValues(alpha: 0.45),
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

/// Themed fallback shown if the camera fails to start (permission denied,
/// no camera hardware, etc.) instead of leaving a blank/broken preview.
class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final isPermissionIssue =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white54, size: 48),
          const SizedBox(height: 16),
          Text(
            isPermissionIssue
                ? 'Camera permission is required to scan.'
                : 'Camera is unavailable right now.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Paints a dimmed scrim over the whole screen with a rounded-rectangle
/// cut-out for the scan area, plus corner "brackets" in the app's accent
/// color to frame the viewfinder.
class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter({
    required this.cutOutRect,
    required this.cutOutRadius,
    required this.accentColor,
  });

  final Rect cutOutRect;
  final double cutOutRadius;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutOutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(cutOutRadius)));

    final scrimPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutOutPath,
    );

    canvas.drawPath(scrimPath, Paint()..color = Colors.black.withValues(alpha: 0.5));

    const cornerLength = 24.0;
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
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.cutOutRect != cutOutRect ||
        oldDelegate.accentColor != accentColor;
  }
}