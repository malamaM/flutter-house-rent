import Flutter
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var videoPreparation: HavenVideoPreparation?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    videoPreparation = HavenVideoPreparation(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}

/// A small application channel instead of another Flutter plugin keeps native
/// media preparation available in both the implicit iOS engine and device
/// builds. AVAssetExportSession uses the system's hardware-assisted codecs when
/// available and leaves already-suitable videos untouched.
private final class HavenVideoPreparation {
  private let channel: FlutterMethodChannel
  private var exports: [String: AVAssetExportSession] = [:]
  private var progressTimers: [String: Timer] = [:]

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "haven/media_preparation",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "prepareVideo" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.prepare(call: call, result: result)
    }
  }

  private func prepare(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String,
      let requestId = arguments["request_id"] as? String
    else {
      result(FlutterError(
        code: "invalid_video_request",
        message: "The selected video path was not available.",
        details: nil
      ))
      return
    }

    let maxDimension = (arguments["max_dimension"] as? NSNumber)?.doubleValue ?? 1920
    let largeByteThreshold =
      (arguments["unusually_large_bytes"] as? NSNumber)?.int64Value ?? 83_886_080
    let sourceURL = URL(fileURLWithPath: path)

    guard FileManager.default.fileExists(atPath: path) else {
      result(FlutterError(
        code: "video_missing",
        message: "The selected video is no longer available.",
        details: nil
      ))
      return
    }

    let asset = AVURLAsset(url: sourceURL)
    guard let track = asset.tracks(withMediaType: .video).first else {
      result(FlutterError(
        code: "video_track_missing",
        message: "The selected file does not contain a readable video track.",
        details: nil
      ))
      return
    }

    let transformedSize = track.naturalSize.applying(track.preferredTransform)
    let longestEdge = max(abs(transformedSize.width), abs(transformedSize.height))
    let attributes = try? FileManager.default.attributesOfItem(atPath: path)
    let bytes = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    let fileExtension = sourceURL.pathExtension.lowercased()
    let containerIsCompatible = ["mp4", "mov", "m4v"].contains(fileExtension)
    let codecIsCompatible = compatibleCodec(for: track)
    let shouldConvert = longestEdge > maxDimension ||
      bytes > largeByteThreshold ||
      !containerIsCompatible ||
      !codecIsCompatible

    guard shouldConvert else {
      result([
        "path": path,
        "converted": false,
        "used_original_fallback": false,
      ])
      return
    }

    let preset = AVAssetExportPreset1920x1080
    guard AVAssetExportSession.exportPresets(compatibleWith: asset).contains(preset),
          let exporter = AVAssetExportSession(asset: asset, presetName: preset) else {
      result(FlutterError(
        code: "video_conversion_unsupported",
        message: "This video cannot be prepared on this device.",
        details: nil
      ))
      return
    }

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("haven-prepared-\(requestId).mp4")
    try? FileManager.default.removeItem(at: outputURL)
    exporter.outputURL = outputURL
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    exports[requestId] = exporter
    startProgress(for: requestId, exporter: exporter)

    exporter.exportAsynchronously { [weak self] in
      DispatchQueue.main.async {
        guard let self else { return }
        self.finishProgress(for: requestId)
        self.exports.removeValue(forKey: requestId)
        switch exporter.status {
        case .completed:
          self.channel.invokeMethod("preparationProgress", arguments: [
            "request_id": requestId,
            "progress": 1.0,
          ])
          result([
            "path": outputURL.path,
            "converted": true,
            "used_original_fallback": false,
          ])
        case .cancelled:
          try? FileManager.default.removeItem(at: outputURL)
          result(FlutterError(
            code: "video_conversion_cancelled",
            message: "Video preparation was cancelled.",
            details: nil
          ))
        default:
          try? FileManager.default.removeItem(at: outputURL)
          result(FlutterError(
            code: "video_conversion_failed",
            message: exporter.error?.localizedDescription ??
              "The video could not be prepared on this device.",
            details: nil
          ))
        }
      }
    }
  }

  private func compatibleCodec(for track: AVAssetTrack) -> Bool {
    guard let description = track.formatDescriptions.first else { return false }
    let subtype = CMFormatDescriptionGetMediaSubType(description as! CMFormatDescription)
    return subtype == kCMVideoCodecType_H264 || subtype == kCMVideoCodecType_HEVC
  }

  private func startProgress(for requestId: String, exporter: AVAssetExportSession) {
    let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self, weak exporter] _ in
      guard let self, let exporter else { return }
      self.channel.invokeMethod("preparationProgress", arguments: [
        "request_id": requestId,
        "progress": Double(exporter.progress),
      ])
    }
    progressTimers[requestId] = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func finishProgress(for requestId: String) {
    progressTimers.removeValue(forKey: requestId)?.invalidate()
  }
}
