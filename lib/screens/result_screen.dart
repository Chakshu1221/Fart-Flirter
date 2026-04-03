import 'dart:async';
import 'package:flutter/material.dart';
import '../models/fart_result.dart';

class ResultScreen extends StatefulWidget {
  final FartResult result;
  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  int    _displayedScore = 0;
  Timer? _scoreTimer;
  late   AnimationController _fadeCtrl;
  late   Animation<double>   _fadeAnim;

  static const _green  = Color(0xFF7FFF00);
  static const _yellow = Color(0xFFFFDD00);
  static const _red    = Color(0xFFFF4444);
  static const _bg     = Color(0xFF0A0A0F);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    if (widget.result.isFart) _animateScore();
  }

  @override
  void dispose() {
    _scoreTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _animateScore() {
    const Duration total    = Duration(milliseconds: 1400);
    const Duration interval = Duration(milliseconds: 16);
    final int target = widget.result.score;
    final int ticks  = total.inMilliseconds ~/ interval.inMilliseconds;
    int tick = 0;

    _scoreTimer = Timer.periodic(interval, (timer) {
      tick++;
      final t      = tick / ticks;
      final eased  = 1 - (1 - t) * (1 - t); // ease-out quad
      setState(() => _displayedScore = (eased * target).round().clamp(0, target));
      if (tick >= ticks) timer.cancel();
    });
  }

  Color get _scoreColor {
    if (!widget.result.isFart)    return _red;
    if (widget.result.score > 80) return _yellow;
    if (widget.result.score > 60) return _green;
    return Colors.white70;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: widget.result.isFart
              ? _buildFartResult()
              : _buildRejectedResult(),
        ),
      ),
    );
  }

  // ── Fart detected ──────────────────────────────────────────────────────────

  Widget _buildFartResult() {
    final r = widget.result;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 24),

            // Big emoji
            Text(r.emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 12),

            // Rank title
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [_green, _yellow],
              ).createShader(b),
              child: Text(
                r.rank.toUpperCase(),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Score circle
            _ScoreCircle(score: _displayedScore, color: _scoreColor),
            const SizedBox(height: 28),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(label: 'LOUDNESS',
                    value: '${r.rmsDb.toStringAsFixed(1)} dB', icon: '🔊'),
                _StatChip(label: 'DURATION',
                    value: '${(r.durationMs / 1000).toStringAsFixed(1)} s', icon: '⏱️'),
                _StatChip(label: 'CERTAINTY',
                    value: '${(r.confidence * 100).toStringAsFixed(0)}%', icon: '🎯'),
              ],
            ),
            const SizedBox(height: 28),

            // Confidence bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FART CONFIDENCE',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 11, letterSpacing: 2)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: r.confidence),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOut,
                    builder: (_, val, __) => LinearProgressIndicator(
                      value: val,
                      minHeight: 10,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation(_green),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),

            _buildTryAgainButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Rejected ───────────────────────────────────────────────────────────────

  Widget _buildRejectedResult() {
    return Column(
      children: [
        _buildTopBar(),
        const Spacer(),
        const Text('😏', style: TextStyle(fontSize: 90)),
        const SizedBox(height: 24),
        const Text('NICE TRY BRO',
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: _red,
            )),
        const SizedBox(height: 16),
        const Text(
          "That wasn't a fart.\nDon't insult the algorithm.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 16, height: 1.6),
        ),
        const Spacer(),
        _buildTryAgainButton(),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Shared ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white38),
          onPressed: () => Navigator.pop(context),
        ),
        const Text('RESULT',
            style: TextStyle(
                fontSize: 18, letterSpacing: 4, color: Colors.white38,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildTryAgainButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          gradient: const LinearGradient(
              colors: [_green, Color(0xFFAAFF00)]),
          boxShadow: [
            BoxShadow(
                color: _green.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: const Text(
          'TRY AGAIN',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: Colors.black,
          ),
        ),
      ),
    );
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
      width: 150, height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.7), width: 3),
        color: color.withOpacity(0.08),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 30, spreadRadius: 4)
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$score',
                style: TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                  shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 12)],
                )),
            Text('SCORE',
                style: TextStyle(
                    color: color.withOpacity(0.6),
                    fontSize: 12, letterSpacing: 3,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value, icon;
  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 15, color: Colors.white,
                fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 9, letterSpacing: 1.5)),
      ]),
    );
  }
}