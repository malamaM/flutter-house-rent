import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

class ReelsMusicService {
  AudioPlayer? _player;
  bool _ready = false;
  bool _disposed = false;
  int _commandVersion = 0;
  Future<void>? _initialization;

  Future<void> play() async {
    if (_disposed) return;
    final command = ++_commandVersion;
    await (_initialization ??= _initialize());
    if (_disposed || command != _commandVersion) return;
    await _player?.resume();
  }

  Future<void> _initialize() async {
    if (_ready || _disposed) return;
    final player = _player ??= AudioPlayer();
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(.32);
    await player.setSourceBytes(
      _buildOriginalAmbientLoop(),
      mimeType: 'audio/wav',
    );
    _ready = true;
  }

  Future<void> pause() async {
    _commandVersion++;
    final player = _player;
    if (player != null) await player.pause();
  }

  Future<void> dispose() async {
    _disposed = true;
    _commandVersion++;
    final player = _player;
    if (player != null) await player.dispose();
    _player = null;
  }

  /// Generates a short original ambient loop at runtime. No third-party song
  /// or copyrighted recording is bundled with Haven.
  Uint8List _buildOriginalAmbientLoop() {
    const sampleRate = 16000;
    const seconds = 16;
    const channels = 1;
    const bitsPerSample = 16;
    const sampleCount = sampleRate * seconds;
    const dataLength = sampleCount * 2;
    final bytes = Uint8List(44 + dataLength);
    final data = ByteData.sublistView(bytes);

    void text(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        data.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    text(0, 'RIFF');
    data.setUint32(4, 36 + dataLength, Endian.little);
    text(8, 'WAVE');
    text(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * channels * 2, Endian.little);
    data.setUint16(32, channels * 2, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    text(36, 'data');
    data.setUint32(40, dataLength, Endian.little);

    const chords = <List<double>>[
      [130.81, 164.81, 196.00, 246.94],
      [110.00, 130.81, 164.81, 196.00],
      [87.31, 130.81, 174.61, 220.00],
      [98.00, 146.83, 196.00, 261.63],
    ];
    for (var i = 0; i < sampleCount; i++) {
      final time = i / sampleRate;
      final chord = chords[(time ~/ 4) % chords.length];
      final chordTime = time % 4;
      final edgeFade = math.min(1.0, math.min(chordTime, 4 - chordTime) * 3);
      var value = 0.0;
      for (var note = 0; note < chord.length; note++) {
        final movement = 1 + .002 * math.sin(2 * math.pi * .08 * time + note);
        value += math.sin(2 * math.pi * chord[note] * movement * time) * .12;
        value += math.sin(2 * math.pi * chord[note] * 2 * time) * .025;
      }
      final beat = time % 2;
      final bellEnvelope = math.exp(-4.2 * beat);
      value += math.sin(2 * math.pi * chord[2] * 4 * time) * bellEnvelope * .09;
      final masterFade = math.min(1.0, math.min(time, seconds - time) * 2);
      final sample =
          (value * edgeFade * masterFade * 22000).clamp(-32767, 32767).round();
      data.setInt16(44 + i * 2, sample, Endian.little);
    }
    return bytes;
  }
}
