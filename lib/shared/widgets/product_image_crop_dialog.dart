import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';

/// Helper function to validate 5MB limit and present the Crop & Confirm Photo dialog.
Future<String?> showProductImageCropDialog({
  required BuildContext context,
  required XFile xfile,
  String title = 'Crop & Confirm Photo',
  String subtitle = 'Pinch or zoom to position the image in the 1:1 frame.',
  bool isCircular = false,
}) async {
  final bytes = await xfile.readAsBytes();
  final fileSize = bytes.length;
  const maxBytes = 5 * 1024 * 1024; // 5 MB limit
  final mbSize = (fileSize / (1024 * 1024)).toStringAsFixed(2);

  if (fileSize > maxBytes) {
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Image Too Large',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected image size is $mbSize MB, which exceeds the maximum allowed 5.0 MB limit for storage.',
                style: const TextStyle(fontSize: 14, color: AppColors.darkText),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please choose a compressed photo or smaller image to save database storage space.',
                        style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Choose Another Image', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    return null;
  }

  // Show Interactive Crop & Confirm Modal Dialog
  if (!context.mounted) return null;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final TransformationController transformationController = TransformationController();

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.secondaryText),
                    onPressed: () => Navigator.pop(dialogContext, null),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                ),
              ),
              const SizedBox(height: 16),

              // 1:1 Crop Viewport with Interactive Viewer
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isCircular ? null : BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryOrange, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: isCircular ? BorderRadius.circular(130) : BorderRadius.circular(14),
                      child: InteractiveViewer(
                        transformationController: transformationController,
                        minScale: 1.0,
                        maxScale: 3.5,
                        child: kIsWeb
                            ? Image.network(
                                xfile.path,
                                width: 260,
                                height: 260,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(xfile.path),
                                width: 260,
                                height: 260,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    // Grid Guidelines overlay for framing
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: isCircular ? null : BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                                  Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                                  Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                                  Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                                  Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                                  Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                                  Expanded(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white12)))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Size & Storage Confirmation Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Passed Size Check ($mbSize MB / Max 5.0 MB)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(dialogContext, null),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(dialogContext, xfile.path),
                      child: const Text(
                        'Confirm Photo',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
