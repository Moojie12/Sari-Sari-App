import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../utils/top_notification.dart';
import 'product_image_crop_dialog.dart';

/// Avatar used on every role's Profile tab and Profile Information screen.
///
/// Shows the uploaded photo when [photoPath] is set, otherwise falls back
/// to [initials] or a user icon. A small camera badge in the corner opens
/// a "Take Photo / Choose from Gallery / Remove Photo" sheet.
class EditableProfileAvatar extends StatefulWidget {
  const EditableProfileAvatar({
    super.key,
    required this.initials,
    this.onPhotoChanged,
    this.photoPath,
    this.radius = 30,
    this.isEditable = true,
  });

  final String initials;
  final String? photoPath;
  final double radius;
  final bool isEditable;

  /// Called with the new photo's local path, or `null` when the person
  /// removes their photo.
  final ValueChanged<String?>? onPhotoChanged;

  @override
  State<EditableProfileAvatar> createState() => _EditableProfileAvatarState();
}

class _EditableProfileAvatarState extends State<EditableProfileAvatar> {
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        if (!mounted) return;
        final confirmedPath = await showProductImageCropDialog(
          context: context,
          xfile: picked,
          title: 'Crop & Confirm Profile Photo',
          subtitle: 'Pinch or zoom to position your profile photo in the frame.',
          isCircular: true,
        );

        if (confirmedPath != null) {
          widget.onPhotoChanged?.call(confirmedPath);
        }
      }
    } catch (_) {
      if (mounted) {
        TopNotification.show(context, "Couldn't access image. Please check app permissions.", isError: true);
      }
    } finally {
      _isPicking = false;
    }
  }

  void _showPhotoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Profile Photo',
                    style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primaryOrange),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryOrange),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (widget.photoPath != null && widget.photoPath!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    widget.onPhotoChanged?.call(null);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarContent() {
    final path = widget.photoPath?.trim();
    final hasPhoto = path != null && path.isNotEmpty;

    if (hasPhoto) {
      // 1. Blob URL (Web) or HTTP / HTTPS network URL
      if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('blob:')) {
        return Image.network(
          path,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackContent(),
        );
      }

      // 2. Base64 Data URI
      if (path.startsWith('data:image')) {
        final commaIndex = path.indexOf(',');
        if (commaIndex != -1) {
          try {
            final bytes = base64Decode(path.substring(commaIndex + 1));
            return Image.memory(
              bytes,
              width: widget.radius * 2,
              height: widget.radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackContent(),
            );
          } catch (_) {}
        }
      }

      // 3. Web platform fallback
      if (kIsWeb) {
        return Image.network(
          path,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackContent(),
        );
      }

      // 4. Asset image path
      if (path.startsWith('assets/')) {
        return Image.asset(
          path,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackContent(),
        );
      }

      // 5. Local File Path (Mobile / Desktop)
      try {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: widget.radius * 2,
            height: widget.radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackContent(),
          );
        }
      } catch (_) {}
    }

    return _buildFallbackContent();
  }

  Widget _buildFallbackContent() {
    final initials = widget.initials.trim();
    if (initials.isNotEmpty) {
      return Center(
        child: Text(
          initials,
          style: TextStyle(
            color: AppColors.primaryOrange,
            fontSize: widget.radius * 0.65,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        Icons.person_rounded,
        size: widget.radius * 1.1,
        color: AppColors.primaryOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: _buildAvatarContent(),
      ),
    );

    if (!widget.isEditable || widget.onPhotoChanged == null) {
      return avatar;
    }

    return GestureDetector(
      onTap: () => _showPhotoOptions(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardWhite, width: 2),
              ),
              child: Icon(Icons.add_a_photo_outlined, size: widget.radius * 0.4, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
