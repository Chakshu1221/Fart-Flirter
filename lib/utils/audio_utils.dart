import 'dart:math' as math;
import 'dart:typed_data';

/// Low-level audio helper functions.
/// All maths work on raw 16-bit signed PCM (little-endian) bytes.
class AudioUtils {
  AudioUtils._();

  static const int _sampleRate = 44100; // Hz — must match recorder config
  static const int _bytesPerSample = 2; // 16-bit PCM

  /// Convert raw PCM [bytes] to a list of normalised float samples (-1.0..1.0).
  static List<double> pcmBytesToFloats(Uint8List bytes) {
    final samples = <double>[];
    // Each sample is 2 bytes, little-endian signed int16
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final int16 = bytes[i] | (bytes[i + 1] << 8);
      // Sign-extend 16-bit to int
      final signed = int16 >= 0x8000 ? int16 - 0x10000 : int16;
      samples.add(signed / 32768.0);
    }
    return samples;
  }

  /// Root-mean-square of normalised float [samples].
  static double rms(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    final sumSq = samples.fold<double>(0.0, (acc, s) => acc + s * s);
    return math.sqrt(sumSq / samples.length);
  }

  /// Convert a linear RMS amplitude (0..1) to decibels.
  /// Returns -96 dB for silence (prevents log(0)).
  static double rmsToDb(double rmsValue) {
    if (rmsValue <= 0) return -96.0;
    return 20.0 * math.log(rmsValue) / math.ln10;
  }

  /// Full pipeline: raw PCM bytes → dB value.
  static double pcmBytesToDb(Uint8List bytes) {
    final floats = pcmBytesToFloats(bytes);
    return rmsToDb(rms(floats));
  }

  /// Duration in milliseconds given the raw byte count and sample rate.
  static int durationMs(int byteCount, {int sampleRate = _sampleRate}) {
    final sampleCount = byteCount ~/ _bytesPerSample;
    return ((sampleCount / sampleRate) * 1000).round();
  }

  /// Clamp [value] between [min] and [max].
  static double clamp(double value, double min, double max) {
    return value < min ? min : (value > max ? max : value);
  }
}