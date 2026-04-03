import 'dart:math' as math;
import 'dart:typed_data';

/// Pure-Dart audio feature extractor.
///
/// Pipeline:
///   raw PCM bytes
///     → normalised float samples
///     → pre-emphasis filter
///     → framing + windowing (Hann)
///     → FFT magnitude spectrum
///     → Mel filter-bank energies
///     → log compression
///     → DCT → MFCC coefficients
///
/// Output shape: [numFrames × numCoeffs] flattened as Float32List.
/// Matches the TFLite model's expected input: (1, 40, 128, 1).
class AudioProcessor {
  AudioProcessor._();

  // ── Hyper-parameters (must match Python training config) ─────────────────
  static const int sampleRate = 44100;
  static const int numMfcc = 40;       // MFCC coefficients per frame
  static const int numFrames = 128;    // Time frames (columns)
  static const int fftSize = 512;      // FFT window size
  static const int hopLength = 256;    // Step between frames
  static const int numMelFilters = 40; // Mel filter-bank bands
  static const double preEmphasis = 0.97;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Convert raw 16-bit PCM [bytes] into a flattened MFCC feature map
  /// of size [numFrames * numMfcc], ready for TFLite inference.
  static Float32List extractMfcc(Uint8List bytes) {
    final samples = _pcmToFloats(bytes);
    final emphasised = _preEmphasise(samples);
    final frames = _frame(emphasised);
    final melBank = _buildMelFilterBank();
    final mfccMatrix = <List<double>>[];

    for (final frame in frames) {
      final windowed = _hann(frame);
      final spectrum = _magnitudeSpectrum(windowed);
      final melEnergies = _applyMelFilters(spectrum, melBank);
      final logMel = melEnergies.map((e) => math.log(e + 1e-9)).toList();
      final coeffs = _dct(logMel, numMfcc);
      mfccMatrix.add(coeffs);
    }

    // Pad or trim to exactly [numFrames] rows
    while (mfccMatrix.length < numFrames) {
      mfccMatrix.add(List.filled(numMfcc, 0.0));
    }
    final trimmed = mfccMatrix.sublist(0, numFrames);

    // Flatten to Float32List: shape (numFrames, numMfcc)
    final flat = Float32List(numFrames * numMfcc);
    for (int i = 0; i < numFrames; i++) {
      for (int j = 0; j < numMfcc; j++) {
        flat[i * numMfcc + j] = trimmed[i][j].toDouble();
      }
    }
    return flat;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static List<double> _pcmToFloats(Uint8List bytes) {
    final out = <double>[];
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final raw = bytes[i] | (bytes[i + 1] << 8);
      final signed = raw >= 0x8000 ? raw - 0x10000 : raw;
      out.add(signed / 32768.0);
    }
    return out;
  }

  /// High-pass pre-emphasis filter reduces low-frequency noise.
  static List<double> _preEmphasise(List<double> s) {
    final out = List<double>.filled(s.length, 0.0);
    out[0] = s[0];
    for (int i = 1; i < s.length; i++) {
      out[i] = s[i] - preEmphasis * s[i - 1];
    }
    return out;
  }

  /// Split signal into overlapping [fftSize]-sample frames.
  static List<List<double>> _frame(List<double> s) {
    final frames = <List<double>>[];
    int start = 0;
    while (start + fftSize <= s.length) {
      frames.add(s.sublist(start, start + fftSize));
      start += hopLength;
    }
    return frames;
  }

  /// Apply Hann window to reduce spectral leakage.
  static List<double> _hann(List<double> frame) {
    final n = frame.length;
    return List.generate(
        n, (i) => frame[i] * 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1))));
  }

  /// Compute magnitude spectrum via DFT (Cooley-Tukey style, power-of-2).
  /// Returns magnitudes for the positive half (fftSize/2 + 1 bins).
  static List<double> _magnitudeSpectrum(List<double> windowed) {
    final n = windowed.length;
    // Real + imaginary arrays
    final real = List<double>.from(windowed);
    final imag = List<double>.filled(n, 0.0);

    // Iterative Cooley-Tukey FFT
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      for (; j & bit != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = real[i]; real[i] = real[j]; real[j] = tr;
        final ti = imag[i]; imag[i] = imag[j]; imag[j] = ti;
      }
    }

    for (int len = 2; len <= n; len <<= 1) {
      final angle = -2 * math.pi / len;
      final wReal = math.cos(angle);
      final wImag = math.sin(angle);
      for (int i = 0; i < n; i += len) {
        double curR = 1.0, curI = 0.0;
        for (int k = 0; k < len ~/ 2; k++) {
          final ur = real[i + k], ui = imag[i + k];
          final vr = real[i + k + len ~/ 2] * curR - imag[i + k + len ~/ 2] * curI;
          final vi = real[i + k + len ~/ 2] * curI + imag[i + k + len ~/ 2] * curR;
          real[i + k] = ur + vr; imag[i + k] = ui + vi;
          real[i + k + len ~/ 2] = ur - vr; imag[i + k + len ~/ 2] = ui - vi;
          final nr = curR * wReal - curI * wImag;
          curI = curR * wImag + curI * wReal;
          curR = nr;
        }
      }
    }

    final half = n ~/ 2 + 1;
    return List.generate(
        half, (i) => math.sqrt(real[i] * real[i] + imag[i] * imag[i]));
  }

  /// Build triangular mel filter bank.
  static List<List<double>> _buildMelFilterBank() {
    double hzToMel(double hz) => 2595 * math.log(1 + hz / 700) / math.ln10;
    double melToHz(double mel) => 700 * (math.pow(10, mel / 2595) - 1);

    final lowMel = hzToMel(0);
    final highMel = hzToMel(sampleRate / 2.0);
    final melPoints =
        List.generate(numMelFilters + 2, (i) => lowMel + i * (highMel - lowMel) / (numMelFilters + 1));
    final hzPoints = melPoints.map(melToHz).toList();
    final binPoints =
        hzPoints.map((hz) => ((fftSize + 1) * hz / sampleRate).floor()).toList();

    final numBins = fftSize ~/ 2 + 1;
    final bank = List.generate(
        numMelFilters, (_) => List<double>.filled(numBins, 0.0));

    for (int m = 1; m <= numMelFilters; m++) {
      final start = binPoints[m - 1];
      final center = binPoints[m];
      final end = binPoints[m + 1];

      for (int k = start; k < center && k < numBins; k++) {
        bank[m - 1][k] = (k - start) / (center - start + 1e-9);
      }
      for (int k = center; k < end && k < numBins; k++) {
        bank[m - 1][k] = (end - k) / (end - center + 1e-9);
      }
    }
    return bank;
  }

  static List<double> _applyMelFilters(
      List<double> spectrum, List<List<double>> bank) {
    return bank.map((filter) {
      double energy = 0;
      for (int i = 0; i < filter.length; i++) {
        if (i < spectrum.length) energy += filter[i] * spectrum[i];
      }
      return energy;
    }).toList();
  }

  /// Type-II DCT to decorrelate mel energies into MFCC coefficients.
  static List<double> _dct(List<double> input, int numCoeffs) {
    final n = input.length;
    return List.generate(numCoeffs, (k) {
      double sum = 0;
      for (int i = 0; i < n; i++) {
        sum += input[i] * math.cos(math.pi * k * (2 * i + 1) / (2 * n));
      }
      return sum * math.sqrt(2.0 / n);
    });
  }
}