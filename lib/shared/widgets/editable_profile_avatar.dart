import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../utils/top_notification.dart';

/// Avatar used on every role's Profile tab and Profile Information screen.
///
/// Shows the uploaded photo when [photoPath] is set, otherwise falls back
/// to [initials]. A small camera badge in the corner opens a "Take Photo /
/// Choose from Gallery / Remove Photo" sheet — this is the "Add Profile"
/// (add/change profile photo) action shared by Owner, Employee, and
/// Customer.
class EditableProfileAvatar extends StatefulWidget {
  const EditableProfileAvatar({
    super.key,
    required this.initials,
    required this.onPhotoChanged,
    this.photoPath,
    this.radius = 30,
  });

  final String initials;
  final String? photoPath;
  final double radius;

  /// Called with the new photo's local path, or `null` when the person
  /// removes their photo.
  final ValueChanged<String?> onPhotoChanged;

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
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        widget.onPhotoChanged(picked.path);
      }
    } catch (_) {
      if (mounted) {
        TopNotification.show(context, "Couldn't access that. Please check app permissions.", isError: true);
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
              if (widget.photoPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    widget.onPhotoChanged(null);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.photoPath != null && widget.photoPath!.isNotEmpty;

    return GestureDetector(
      onTap: () => _showPhotoOptions(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: widget.radius,
            backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.12),
            backgroundImage: hasPhoto ? FileImage(File(widget.photoPath!)) : null,
            child: hasPhoto
                ? null
                : Text(
              widget.initials,
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontSize: widget.radius * 0.65,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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