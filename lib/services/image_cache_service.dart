import 'package:flutter/foundation.dart';
import '../auth_service.dart';

/// Service to handle image preloading and caching
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final Map<String, Uint8List> _cache = {};
  final Set<String> _downloading = {};

  /// Preload multiple images concurrently
  Future<void> preloadImages(List<String> attachmentIds) async {
    final futures = attachmentIds
        .where((id) => !_cache.containsKey(id) && !_downloading.contains(id))
        .map((id) => _downloadAndCache(id));
    
    await Future.wait(futures);
  }

  /// Download and cache a single image
  Future<void> _downloadAndCache(String attachmentId) async {
    if (_cache.containsKey(attachmentId) || _downloading.contains(attachmentId)) {
      return;
    }

    _downloading.add(attachmentId);

    try {
      final authService = AuthService();
      final result = await authService.downloadAttachment(attachmentId);

      if (result.success && result.fileBytes != null) {
        _cache[attachmentId] = Uint8List.fromList(result.fileBytes!);
        debugPrint('✓ Cached image: $attachmentId');
      }
    } catch (e) {
      debugPrint('✗ Error caching image $attachmentId: $e');
    } finally {
      _downloading.remove(attachmentId);
    }
  }

  /// Get cached image bytes
  Uint8List? getCachedImage(String attachmentId) {
    return _cache[attachmentId];
  }

  /// Check if image is cached
  bool isCached(String attachmentId) {
    return _cache.containsKey(attachmentId);
  }

  /// Clear all cached images
  void clearCache() {
    _cache.clear();
  }

  /// Remove specific image from cache
  void removeFromCache(String attachmentId) {
    _cache.remove(attachmentId);
  }
}
