/// Data class representing the full result of one recording session.
class FartResult {
  /// Whether the ML model classified the sound as a fart.
  final bool isFart;

  /// Model confidence for the winning class (0.0 – 1.0).
  final double confidence;

  /// Final calculated score (0 – 100).
  final int score;

  /// Rank title string, e.g. "Thunder King".
  final String rank;

  /// Emoji matching the rank, e.g. "⚡".
  final String emoji;

  /// Length of the recorded clip in milliseconds.
  final int durationMs;

  /// Root-mean-square audio level converted to decibels.
  final double rmsDb;

  const FartResult({
    required this.isFart,
    required this.confidence,
    required this.score,
    required this.rank,
    required this.emoji,
    required this.durationMs,
    required this.rmsDb,
  });

  /// Convenience factory for a rejected (non-fart) result.
  factory FartResult.rejected() => const FartResult(
        isFart: false,
        confidence: 0,
        score: 0,
        rank: 'Nice Try Bro',
        emoji: '😏',
        durationMs: 0,
        rmsDb: 0,
      );

  @override
  String toString() =>
      'FartResult(isFart: $isFart, score: $score, rank: $rank, '
      'confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
      'rmsDb: ${rmsDb.toStringAsFixed(1)} dB, duration: ${durationMs}ms)';
}