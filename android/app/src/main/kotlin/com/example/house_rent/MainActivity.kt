package com.example.house_rent

import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.ScaleAndRotateTransformation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

@OptIn(UnstableApi::class)
class MainActivity: FlutterActivity() {
    private val mediaChannelName = "haven/media_preparation"
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var mediaChannel: MethodChannel
    private val activeTransformers = mutableMapOf<String, Transformer>()
    private val progressTasks = mutableMapOf<String, Runnable>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        // Some manufacturers reset the preferred mode after backgrounding or
        // power-mode changes, so renew the preference when Haven becomes active.
        requestHighestRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            mediaChannelName,
        )
        mediaChannel.setMethodCallHandler { call, result ->
            if (call.method != "prepareVideo") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            val requestId = call.argument<String>("request_id")
            if (path.isNullOrBlank() || requestId.isNullOrBlank()) {
                result.error(
                    "invalid_video_request",
                    "The selected video path was not available.",
                    null,
                )
                return@setMethodCallHandler
            }
            prepareVideo(
                sourcePath = path,
                requestId = requestId,
                maxDimension = call.argument<Number>("max_dimension")?.toInt() ?: 1920,
                largeByteThreshold =
                    call.argument<Number>("unusually_large_bytes")?.toLong() ?: 83_886_080L,
                result = result,
            )
        }
    }

    private fun prepareVideo(
        sourcePath: String,
        requestId: String,
        maxDimension: Int,
        largeByteThreshold: Long,
        result: MethodChannel.Result,
    ) {
        val source = File(sourcePath)
        if (!source.isFile) {
            result.error(
                "video_missing",
                "The selected video is no longer available.",
                null,
            )
            return
        }

        val metadata = readVideoMetadata(sourcePath)
        if (metadata == null) {
            result.error(
                "video_track_missing",
                "The selected file does not contain a readable video track.",
                null,
            )
            return
        }

        val compatibleContainer = source.extension.lowercase() in setOf("mp4", "mov", "m4v")
        val compatibleCodec = metadata.mimeType == MimeTypes.VIDEO_H264 ||
            metadata.mimeType == MimeTypes.VIDEO_H265
        val longestEdge = maxOf(metadata.displayWidth, metadata.displayHeight)
        val shouldConvert = longestEdge > maxDimension ||
            source.length() > largeByteThreshold ||
            !compatibleContainer ||
            !compatibleCodec

        if (!shouldConvert) {
            result.success(
                mapOf(
                    "path" to sourcePath,
                    "converted" to false,
                    "used_original_fallback" to false,
                ),
            )
            return
        }

        val outputDirectory = File(cacheDir, "haven_video_preparation").apply { mkdirs() }
        val output = File(outputDirectory, "haven-prepared-$requestId.mp4")
        if (output.exists()) output.delete()

        val videoEffects = mutableListOf<Effect>()
        if (longestEdge > maxDimension) {
            val scale = maxDimension.toFloat() / longestEdge.toFloat()
            videoEffects.add(
                ScaleAndRotateTransformation.Builder()
                    .setScale(scale, scale)
                    .build(),
            )
        }
        val editedMediaItem = EditedMediaItem.Builder(
            MediaItem.fromUri(Uri.fromFile(source)),
        ).setEffects(Effects(emptyList(), videoEffects)).build()

        val transformer = Transformer.Builder(applicationContext)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    stopProgress(requestId)
                    activeTransformers.remove(requestId)
                    mediaChannel.invokeMethod(
                        "preparationProgress",
                        mapOf("request_id" to requestId, "progress" to 1.0),
                    )
                    result.success(
                        mapOf(
                            "path" to output.absolutePath,
                            "converted" to true,
                            "used_original_fallback" to false,
                        ),
                    )
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    stopProgress(requestId)
                    activeTransformers.remove(requestId)
                    output.delete()
                    result.error(
                        "video_conversion_failed",
                        exportException.localizedMessage
                            ?: "The video could not be prepared on this device.",
                        null,
                    )
                }
            })
            .build()

        activeTransformers[requestId] = transformer
        try {
            transformer.start(editedMediaItem, output.absolutePath)
            startProgress(requestId, transformer)
        } catch (error: Exception) {
            activeTransformers.remove(requestId)
            output.delete()
            result.error(
                "video_conversion_failed",
                error.localizedMessage ?: "The video could not be prepared on this device.",
                null,
            )
        }
    }

    private fun readVideoMetadata(path: String): VideoMetadata? {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(path)
            for (index in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(index)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("video/")) continue
                var width = format.getInteger(MediaFormat.KEY_WIDTH)
                var height = format.getInteger(MediaFormat.KEY_HEIGHT)
                val rotation = if (format.containsKey(MediaFormat.KEY_ROTATION)) {
                    format.getInteger(MediaFormat.KEY_ROTATION)
                } else {
                    0
                }
                if (rotation == 90 || rotation == 270) {
                    val originalWidth = width
                    width = height
                    height = originalWidth
                }
                return VideoMetadata(width, height, mime)
            }
            null
        } catch (_: Exception) {
            null
        } finally {
            extractor.release()
        }
    }

    private fun startProgress(requestId: String, transformer: Transformer) {
        val progressHolder = ProgressHolder()
        val task = object : Runnable {
            override fun run() {
                if (activeTransformers[requestId] !== transformer) return
                val state = transformer.getProgress(progressHolder)
                if (state == Transformer.PROGRESS_STATE_AVAILABLE) {
                    mediaChannel.invokeMethod(
                        "preparationProgress",
                        mapOf(
                            "request_id" to requestId,
                            "progress" to progressHolder.progress / 100.0,
                        ),
                    )
                }
                if (state != Transformer.PROGRESS_STATE_NOT_STARTED) {
                    mainHandler.postDelayed(this, 250)
                }
            }
        }
        progressTasks[requestId] = task
        mainHandler.post(task)
    }

    private fun stopProgress(requestId: String) {
        progressTasks.remove(requestId)?.let(mainHandler::removeCallbacks)
    }

    private data class VideoMetadata(
        val displayWidth: Int,
        val displayHeight: Int,
        val mimeType: String,
    )

    private fun requestHighestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        } ?: return

        val currentMode = currentDisplay.mode
        val bestMode = currentDisplay.supportedModes
            .asSequence()
            // Never trade resolution for refresh rate. Only compare modes at
            // the display's current native dimensions.
            .filter {
                it.physicalWidth == currentMode.physicalWidth &&
                    it.physicalHeight == currentMode.physicalHeight
            }
            .maxByOrNull { it.refreshRate }
            ?: return

        val attributes = window.attributes
        attributes.preferredDisplayModeId = bestMode.modeId
        attributes.preferredRefreshRate = bestMode.refreshRate
        window.attributes = attributes
    }
}
