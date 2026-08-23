import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef VideoPreparationProgress = void Function(double progress);

/// The result of Haven's best-effort, on-device video preparation.
///
/// A failed conversion is deliberately not an error to the listing flow. In
/// that case [path] points to the original selection and Laravel performs the
/// final validation and normalization as usual.
class PreparedVideo {
  final String path;
  final String originalPath;
  final bool converted;
  final bool usedOriginalFallback;
  final int originalBytes;
  final int preparedBytes;

  const PreparedVideo({
    required this.path,
    required this.originalPath,
    required this.converted,
    required this.usedOriginalFallback,
    required this.originalBytes,
    required this.preparedBytes,
  });

  Future<void> deleteTemporaryCopy() async {
    if (!converted || path == originalPath) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Cache files are also cleared by the operating system. Cleanup must
      // never turn a successfully selected video into a failed listing.
    }
  }
}

/// Coordinates adaptive native preparation through AVFoundation on iOS and
/// Media3/MediaCodec on Android.
class VideoPreparationService {
  VideoPreparationService._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final VideoPreparationService instance = VideoPreparationService._();
  static const MethodChannel _channel =
      MethodChannel('haven/media_preparation');

  /// Clips above this size are considered unusually large even at 1080p.
  static const int unusuallyLargeBytes = 80 * 1024 * 1024;
  static const int maxDimension = 1920;

  final Map<String, VideoPreparationProgress> _progressListeners = {};
  int _requestSequence = 0;

  Future<PreparedVideo> prepare(
    String path, {
    VideoPreparationProgress? onProgress,
  }) async {
    final original = File(path);
    final originalBytes = await original.length();
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      return _original(path, originalBytes);
    }

    final requestId =
        '${DateTime.now().microsecondsSinceEpoch}-${_requestSequence++}';
    if (onProgress != null) _progressListeners[requestId] = onProgress;
    onProgress?.call(0);

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'prepareVideo',
        <String, dynamic>{
          'path': path,
          'request_id': requestId,
          'max_dimension': maxDimension,
          'unusually_large_bytes': unusuallyLargeBytes,
        },
      ).timeout(const Duration(minutes: 20));

      final preparedPath = response?['path']?.toString() ?? path;
      final prepared = File(preparedPath);
      if (!await prepared.exists()) return _original(path, originalBytes, true);
      final preparedBytes = await prepared.length();
      final converted = response?['converted'] == true && preparedPath != path;

      if (preparedBytes <= 0) {
        if (converted) await _safeDelete(prepared);
        return _original(path, originalBytes, true);
      }

      onProgress?.call(1);
      return PreparedVideo(
        path: preparedPath,
        originalPath: path,
        converted: converted,
        usedOriginalFallback: response?['used_original_fallback'] == true,
        originalBytes: originalBytes,
        preparedBytes: preparedBytes,
      );
    } on MissingPluginException {
      return _original(path, originalBytes, true);
    } on PlatformException {
      return _original(path, originalBytes, true);
    } on TimeoutException {
      return _original(path, originalBytes, true);
    } catch (_) {
      return _original(path, originalBytes, true);
    } finally {
      _progressListeners.remove(requestId);
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'preparationProgress') return;
    final arguments = Map<String, dynamic>.from(call.arguments as Map);
    final requestId = arguments['request_id']?.toString();
    final value = (arguments['progress'] as num?)?.toDouble();
    if (requestId == null || value == null) return;
    _progressListeners[requestId]?.call(value.clamp(0, 1).toDouble());
  }

  PreparedVideo _original(String path, int bytes, [bool fallback = false]) =>
      PreparedVideo(
        path: path,
        originalPath: path,
        converted: false,
        usedOriginalFallback: fallback,
        originalBytes: bytes,
        preparedBytes: bytes,
      );

  Future<void> _safeDelete(File file) async {
    try {
      await file.delete();
    } catch (_) {}
  }
}
