import 'dart:io';

class MediaUploadException implements Exception {
  final String message;

  const MediaUploadException(this.message);

  @override
  String toString() => message;
}

/// One source of truth for the media limits enforced by the Haven API.
class MediaUploadPolicy {
  // Raw selection limits are intentionally generous. The API normalizes and
  // compresses accepted media before permanent storage.
  static const int maxImageBytes = 25 * 1024 * 1024;
  static const int maxVerificationFileBytes = 25 * 1024 * 1024;
  static const int maxVideoBytes = 300 * 1024 * 1024;
  static const int maxReelVideoBytes = 300 * 1024 * 1024;
  static const int maxListingRequestBytes = 640 * 1024 * 1024;
  static const int maxGalleryImages = 12;
  static const int maxRegularVideos = 4;

  const MediaUploadPolicy._();

  static Future<int> validateFile(String path,
      {required int maxBytes, required String label}) async {
    final file = File(path);
    if (!await file.exists()) {
      throw MediaUploadException(
          '$label is no longer available. Choose it again.');
    }
    final bytes = await file.length();
    if (bytes <= 0) {
      throw MediaUploadException(
          '$label is empty or unreadable. Choose another file.');
    }
    if (bytes > maxBytes) {
      throw MediaUploadException(
        '$label is ${formatBytes(bytes)}. The maximum is ${formatBytes(maxBytes)}.',
      );
    }
    return bytes;
  }

  static Future<void> validateListing({
    String? coverImagePath,
    List<String> galleryImagePaths = const [],
    List<String> videoPaths = const [],
    String? reelVideoPath,
  }) async {
    if (galleryImagePaths.length > maxGalleryImages) {
      throw const MediaUploadException(
          'A listing can have up to 12 gallery photos.');
    }
    if (videoPaths.length > maxRegularVideos) {
      throw const MediaUploadException(
          'A listing can have up to 4 regular videos.');
    }

    var total = 0;
    if (coverImagePath != null) {
      total += await validateFile(coverImagePath,
          maxBytes: maxImageBytes, label: 'Cover photo');
    }
    for (var i = 0; i < galleryImagePaths.length; i++) {
      total += await validateFile(galleryImagePaths[i],
          maxBytes: maxImageBytes, label: 'Gallery photo ${i + 1}');
    }
    for (var i = 0; i < videoPaths.length; i++) {
      total += await validateFile(videoPaths[i],
          maxBytes: maxVideoBytes, label: 'Video ${i + 1}');
    }
    if (reelVideoPath != null) {
      total += await validateFile(reelVideoPath,
          maxBytes: maxReelVideoBytes, label: 'Featured reel video');
    }
    if (total > maxListingRequestBytes) {
      throw MediaUploadException(
        'This upload is ${formatBytes(total)} in total. Reduce it below '
        '${formatBytes(maxListingRequestBytes)} and try again.',
      );
    }
  }

  static String formatBytes(int bytes) {
    final megabytes = bytes / (1024 * 1024);
    return megabytes >= 10
        ? '${megabytes.round()} MB'
        : '${megabytes.toStringAsFixed(1)} MB';
  }
}
