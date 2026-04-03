import '../models/fart_result.dart';
import '../utils/audio_utils.dart';

/// Turns raw detection metrics into a final [FartResult].
class ScoringService {
  ScoringService._();

  /// Compute a score and select a rank given detection metrics.
  ///
  /// Parameters:
  ///   [isFart]      — did the ML model classify as fart?
  ///   [confidence]  — model probability for the fart class (0.0–1.0)
  ///   [rmsDb]       — audio loudness in decibels (typically -96 … 0)
  ///   [durationMs]  — recording length in milliseconds
  static FartResult evaluate({
    required bool isFart,
    required double confidence,
    required double rmsDb,
    required int durationMs,
  }) {
    if (!isFart) return FartResult.rejected();

    // ── Scoring formula ─────────────────────────────────────────────────────
    //   confidence component  : up to 40 pts  (model certainty)
    //   loudness component     : up to 35 pts  (rmsDb normalised against 80 dB)
    //   duration component     : up to 25 pts  (up to 5 s clip)

    // rmsDb is negative; bring it to a positive 0–80 scale:
    //   e.g. -10 dB → (80 - 10) / 80 ≈ 0.875
    final loudnessNorm = AudioUtils.clamp((rmsDb + 80) / 80, 0, 1);
    final durationNorm = AudioUtils.clamp(durationMs / 5000.0, 0, 1);

    final rawScore = (confidence * 40) + (loudnessNorm * 35) + (durationNorm * 25);
    final score = rawScore.clamp(0.0, 100.0).round();

    final (:rank, :emoji) = _rankFromScore(score);

    return FartResult(
      isFart: true,
      confidence: confidence,
      score: score,
      rank: rank,
      emoji: emoji,
      durationMs: durationMs,
      rmsDb: rmsDb,
    );
  }

  // ── Rank table ────────────────────────────────────────────────────────────

  static ({String rank, String emoji}) _rankFromScore(int score) {
    if (score <= 20) return (rank: 'Silent Ninja',    emoji: '🥷');
    if (score <= 40) return (rank: 'Stealth Mode',    emoji: '👻');
    if (score <= 60) return (rank: 'Classic Blaster', emoji: '💨');
    if (score <= 80) return (rank: 'Thunder King',    emoji: '⚡');
    return               (rank: 'Earth Shaker',       emoji: '🌍');
  }
}