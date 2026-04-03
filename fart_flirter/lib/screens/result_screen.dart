import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/fart_result.dart';

class ResultScreen extends StatefulWidget {
  final FartResult result;

  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int _displayedScore = 0;
  Timer? _scoreTimer;

  static const _green = Color(0xFF7FFF00);
  static const _yellow = Color(0xFFFFDD00);
  static const _red = Color(0xFFFF3C3C);
  static const _bg = Color(0xFF0A0A0F);

  @override
  void initState() {
    super.initState();
    if (widget.result.isFart) _animateScore();
  }

  @override
  void dispose() {
    _scoreTimer?.cancel();
    super.dispose();
  }

  void _animateScore() {
    const totalDuration = Duration(milliseconds: 1400);
    const tickInterval = Duration(milliseconds: 16); // ~60fps
    final target = widget.result.score;
    final ticks = totalDuration.inMilliseconds ~/ tickInterval.inMilliseconds;
    int tick = 0;

    _scoreTimer = Timer.periodic(tickInterval, (timer) {
      tick++;
      final progress = tick / ticks;
      // Ease-out curve
      final eased = 1 - (1 - progress) * (1 - progress);
      setState(() {
        _displayedScore = (eased * target).round().clamp(0, target);
      });
      if (tick >= ticks) timer.cancel();
    });
  }

  Color get _scoreColor {
    if (!widget.result.isFart) return _red;
    if (widget.result.score > 80) return _yellow;
    if (widget.result.score > 60) return _green;
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: widget.result.isFart ? _buildFartResult() : _buildRejectedResult(),
      ),
    );
  }

  // ── Fart detected ──────────────────────────────────────────────────────────

  Widget _buildFartResult() {
    final r = widget.result;
    return Column(
      children: [
        _buildTopBar(),
        const Spacer(),

        // Big emoji
        Text(r.emoji, style: const TextStyle(fontSize: 80))
            .animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut)
            .fadeIn(duration: 300.ms),

        const SizedBox(height: 16),

        // Rank title
        Text(
          r.rank.toUpperCase(),
          style: GoogleFonts.bangers(
            fontSize: 48,
            letterSpacing: 4,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [_green, _yellow],
              ).createShader(const Rect.fromLTWH(0, 0, 300, 60)),
            shadows: [
              Shadow(color: _green.withOpacity(0.5), blurRadius: 20),
            ],
          ),
        ).animate(delay: 400.ms).scale(begin: const Offset(0.5, 0.5), duration: 500.ms, curve: Curves.elasticOut)
         .fadeIn(),

        const SizedBox(height: 32),

        // Score circle
        _ScoreCircle(score: _displayedScore, color: _scoreColor),

        const SizedBox(height: 32),

        // Stats row
        _buildStatsRow(r),

        const Spacer(),

        // Confidence bar
        _buildConfidenceBar(r.confidence),

        const SizedBox(height: 32),

        _buildTryAgainButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStatsRow(FartResult r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatChip(
            label: 'LOUDNESS',
            value: '${r.rmsDb.toStringAsFixed(1)} dB',
            icon: '🔊',
          ),
          _StatChip(
            label: 'DURATION',
            value: '${(r.durationMs / 1000).toStringAsFixed(1)} s',
            icon: '⏱️',
          ),
          _StatChip(
            label: 'CERTAINTY',
            value: '${(r.confidence * 100).toStringAsFixed(0)}%',
            icon: '🎯',
          ),
        ],
      ),
    ).animate(delay: 700.ms).fadeIn(duration: 400.ms).moveY(begin: 20);
  }

  Widget _buildConfidenceBar(double confidence) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FART CONFIDENCE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: confidence),
              duration: 1200.ms,
              curve: Curves.easeOut,
              builder: (_, val, __) => LinearProgressIndicator(
                value: val,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(_green),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 900.ms).fadeIn();
  }

  // ── Rejected ───────────────────────────────────────────────────────────────

  Widget _buildRejectedResult() {
    return Column(
      children: [
        _buildTopBar(),
        const Spacer(),
        const Text('😏', style: TextStyle(fontSize: 90))
            .animate().shake(duration: 600.ms, delay: 200.ms),
        const SizedBox(height: 24),
        Text(
          'NICE TRY BRO',
          style: GoogleFonts.bangers(
            fontSize: 46,
            letterSpacing: 4,
            color: _red,
            shadows: [Shadow(color: _red.withOpacity(0.5), blurRadius: 20)],
          ),
        ).animate(delay: 300.ms).fadeIn().scale(begin: const Offset(0.7, 0.7), curve: Curves.elasticOut),
        const SizedBox(height: 16),
        Text(
          "That wasn't a fart.\nDon't insult the algorithm.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
            height: 1.5,
          ),
        ).animate(delay: 500.ms).fadeIn(),
        const Spacer(),
        _buildTryAgainButton(),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white38),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'RESULT',
            style: GoogleFonts.bangers(
              fontSize: 20,
              letterSpacing: 4,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTryAgainButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          gradient: const LinearGradient(colors: [_green, Color(0xFFAAFF00)]),
          boxShadow: [
            BoxShadow(color: _green.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Text(
          'TRY AGAIN',
          style: GoogleFonts.bangers(
            fontSize: 22,
            letterSpacing: 3,
            color: Colors.black,
          ),
        ),
      ),
    ).animate(delay: 1000.ms)
     .fadeIn(duration: 400.ms)
     .moveY(begin: 20, duration: 400.ms, curve: Curves.easeOut);
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _ScoreCircle extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreCircle({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.6), width: 3),
        color: color.withOpacity(0.08),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 30, spreadRadius: 4),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score',
              style: GoogleFonts.bangers(
                fontSize: 58,
                color: color,
                height: 1,
                shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 12)],
              ),
            ),
            Text(
              'SCORE',
              style: TextStyle(
                color: color.withOpacity(0.6),
                fontSize: 12,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.bangers(
                fontSize: 16, color: Colors.white, letterSpacing: 1),
          ),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 9, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }
}