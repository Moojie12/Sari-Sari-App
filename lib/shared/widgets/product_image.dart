import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Reusable widget for rendering product images cleanly across all screens.
/// Supports Supabase/Firebase network URLs, Base64 data URIs, local file paths,
/// asset fallbacks, and placeholder icons when no photo is provided.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.image,
    this.width = 56,
    this.height = 56,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_outlined,
  });

  final String? image;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final img = image?.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.lightPeach,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: _buildImageContent(img),
      ),
    );
  }

  Widget _buildImageContent(String? img) {
    if (img == null || img.isEmpty) {
      return _buildPlaceholder();
    }

    // 1. Base64 Data URI
    if (img.startsWith('data:image/')) {
      try {
        final commaIdx = img.indexOf(',');
        if (commaIdx != -1) {
          final base64Data = img.substring(commaIdx + 1);
          final Uint8List bytes = base64Decode(base64Data);
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        }
      } catch (_) {
        return _buildPlaceholder();
      }
    }

    // 2. Network URL (Supabase, Firebase, or other CDN)
    if (img.startsWith('http://') || img.startsWith('https://')) {
      return Image.network(
        img,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryOrange,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    // 3. Asset Image
    if (img.startsWith('assets/')) {
      return Image.asset(
        img,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    // 4. Local File Path
    try {
      final file = File(img);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    } catch (_) {}

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        fallbackIcon,
        color: AppColors.secondaryText.withValues(alpha: 0.5),
        size: (width * 0.45).clamp(16.0, 48.0),
      ),
    );
  }
}
