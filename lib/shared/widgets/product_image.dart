import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  // In-memory static caches to prevent re-decoding base64 data URIs and
  // repeated synchronous file system checks on every scroll frame / rebuild.
  static final Map<String, Uint8List> _base64Cache = <String, Uint8List>{};
  static final Map<String, bool> _fileExistsCache = <String, bool>{};

  /// Clears the static image caches (e.g. after uploading or editing a product image).
  static void clearCache() {
    _base64Cache.clear();
    _fileExistsCache.clear();
  }

  static Uint8List? _getDecodedBase64(String img) {
    if (_base64Cache.containsKey(img)) {
      return _base64Cache[img];
    }
    try {
      final commaIdx = img.indexOf(',');
      if (commaIdx != -1) {
        final base64Data = img.substring(commaIdx + 1);
        final bytes = base64Decode(base64Data);
        if (_base64Cache.length > 300) {
          _base64Cache.remove(_base64Cache.keys.first);
        }
        _base64Cache[img] = bytes;
        return bytes;
      }
    } catch (_) {}
    return null;
  }

  static bool _checkFileExists(String path) {
    if (_fileExistsCache.containsKey(path)) {
      return _fileExistsCache[path]!;
    }
    try {
      final exists = File(path).existsSync();
      if (_fileExistsCache.length > 300) {
        _fileExistsCache.remove(_fileExistsCache.keys.first);
      }
      _fileExistsCache[path] = exists;
      return exists;
    } catch (_) {
      return false;
    }
  }

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

    final double? imageWidth = (width.isFinite && width > 0) ? width : null;
    final double? imageHeight = (height.isFinite && height > 0) ? height : null;

    int? targetCacheWidth;
    int? targetCacheHeight;

    if (imageWidth != null) {
      targetCacheWidth = (imageWidth * 2.5).round().clamp(80, 1080);
    }
    if (imageHeight != null) {
      targetCacheHeight = (imageHeight * 2.5).round().clamp(80, 1080);
    }

    // 1. Base64 Data URI
    if (img.startsWith('data:image/')) {
      final bytes = _getDecodedBase64(img);
      if (bytes != null) {
        return Image.memory(
          bytes,
          key: ValueKey(img),
          width: imageWidth,
          height: imageHeight,
          fit: fit,
          cacheWidth: targetCacheWidth,
          cacheHeight: targetCacheHeight,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
      return _buildPlaceholder();
    }

    // 2. Network / Web Blob URL (Supabase, Firebase, CDN, or Web Blob)
    if (img.startsWith('http://') || img.startsWith('https://') || img.startsWith('blob:')) {
      return Image.network(
        img,
        key: ValueKey(img),
        width: imageWidth,
        height: imageHeight,
        fit: fit,
        cacheWidth: kIsWeb ? null : targetCacheWidth,
        cacheHeight: kIsWeb ? null : targetCacheHeight,
        gaplessPlayback: true,
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

    // 3. Web Platform Fallback for local web paths
    if (kIsWeb) {
      return Image.network(
        img,
        key: ValueKey(img),
        width: imageWidth,
        height: imageHeight,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    // 4. Asset Image
    if (img.startsWith('assets/')) {
      return Image.asset(
        img,
        key: ValueKey(img),
        width: imageWidth,
        height: imageHeight,
        fit: fit,
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    // 5. Local File Path (Mobile / Desktop)
    try {
      String cleanPath = img;
      if (cleanPath.startsWith('file://')) {
        cleanPath = cleanPath.substring(7);
      }
      if (_checkFileExists(cleanPath)) {
        return Image.file(
          File(cleanPath),
          key: ValueKey(cleanPath),
          width: imageWidth,
          height: imageHeight,
          fit: fit,
          cacheWidth: targetCacheWidth,
          cacheHeight: targetCacheHeight,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    } catch (_) {}

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    final effectiveWidth = (width.isFinite && width > 0) ? width : 56.0;
    return Center(
      child: Icon(
        fallbackIcon,
        color: AppColors.secondaryText.withValues(alpha: 0.5),
        size: (effectiveWidth * 0.45).clamp(16.0, 48.0),
      ),
    );
  }
}
