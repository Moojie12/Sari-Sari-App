import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';

/// Utility class implementing mobile best-practice Just-In-Time (JIT)
/// Camera Permission checks and user guidance dialogs.
class CameraPermissionHelper {
  CameraPermissionHelper._();

  /// Ensures camera permission is granted before launching camera/scanner features.
  /// - If granted: returns `true`.
  /// - If denied: prompts OS permission dialog.
  /// - If permanently denied: presents a friendly explanation dialog with an "Open Settings" shortcut.
  static Future<bool> ensureCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final requested = await Permission.camera.request();
      if (requested.isGranted) {
        return true;
      }
    }

    // Permanently denied or rejected -> Show explanation dialog with Settings link
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.camera_alt_outlined, color: AppColors.primaryOrange),
              SizedBox(width: 8),
              Text('Camera Access Needed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Camera permission is needed to scan barcodes and capture product photos. Please enable camera access in your device settings.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    return false;
  }
}
