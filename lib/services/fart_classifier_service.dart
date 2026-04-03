import 'dart:typed_data';
import 'package:flutter/foundation.dart';

// Conditional import: on web dart.library.html is available → use stub
// On mobile dart.library.io is available → use real tflite_flutter
import 'tflite_stub.dart'
    if (dart.library.io) 'package:tflite_flutter/tflite_flutter.dart';

/// Fart classifier.
/// • Mobile → real TFLite CNN model
/// • Web    → pure-Dart energy-based heuristic
class FartClassifierService {
  Interpreter? _interpreter;
  static const double threshold = 0.70;

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('FartClassifier: Web mode — rule-based heuristic');
      return;
    }
    try {
      _interpreter =
          await Interpreter.fromAsset('assets/models/fart_classifier.tflite');
      debugPrint('FartClassifier: TFLite loaded ✅');
    } catch (e) {
      debugPrint('FartClassifier: model load failed ($e) — using heuristic');
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  ({bool isFart, double confidence}) classify(Float32List features) {
    if (!kIsWeb && _interpreter != null) {
      return _tfliteInference(features);
    }
    return _ruleBasedClassify(features);
  }

  // ── TFLite (mobile) ──────────────────────────────────────────────────────

  ({bool isFart, double confidence}) _tfliteInference(Float32List features) {
    const numFrames = 128, numCoeffs = 40;
    final input = List.generate(
      1,
      (_) => List.generate(numFrames,
          (f) => List.generate(numCoeffs, (c) => [features[f * numCoeffs + c]])),
    );
    final output = List.generate(1, (_) => List<double>.filled(2, 0.0));
    _interpreter!.run(input, output);
    final prob = output[0][1];
    return (isFart: prob >= threshold, confidence: prob);
  }

  // ── Rule-based heuristic (web) ───────────────────────────────────────────

  ({bool isFart, double confidence}) _ruleBasedClassify(Float32List features) {
    const numFrames = 128, numCoeffs = 40;
    double lowE = 0, midE = 0, highE = 0;
    int activeFrames = 0;

    for (int f = 0; f < numFrames; f++) {
      double frameE = 0;
      for (int c = 0; c < numCoeffs; c++) {
        final v = features[f * numCoeffs + c].abs();
        if (c >= 1 && c <= 6)  lowE  += v;
        if (c >= 7 && c <= 14) midE  += v;
        if (c >= 15)           highE += v;
        frameE += v;
      }
      if (frameE > 0.5) activeFrames++;
    }

    lowE  /= numFrames;
    midE  /= numFrames;
    highE /= numFrames;
    final total = lowE + midE + highE;
    if (total < 0.1) return (isFart: false, confidence: 0.05);

    final highRatio   = highE / (total + 1e-9);
    final lowMidScore = (lowE + midE) / (total + 1e-9);
    final continuity  = activeFrames / numFrames;

    final confidence = ((lowMidScore * 0.5) +
            (continuity * 0.3) +
            ((1 - highRatio) * 0.2))
        .clamp(0.0, 1.0);

    return (isFart: confidence >= threshold, confidence: confidence);
  }
}