import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A hold-to-record button with animated ripple rings while recording.
class RecordButton extends StatefulWidget {
  /// Called when the user starts pressing (recording begins).
  final VoidCallback onRecordStart;

  /// Called when the user lifts their finger (recording stops).
  final VoidCallback onRecordStop;

  /// Whether a recording is currently in progress.
  final bool isRecording;

  const RecordButton({
    super.key,
    required this.onRecordStart,
    required this.onRecordStop,
    required this.isRecording,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with TickerProviderStateMixin {
  late final AnimationController _ripple1;
  late final AnimationController _ripple2;
  late final AnimationController _ripple3;

  static const _primary = Color(0xFF7FFF00);
  static const _recording = Color(0xFFFF3C3C);

  @override
  void initState() {
    super.initState();
    _ripple1 = AnimationController(vsync: this, duration: 1500.ms)
      ..repeat();
    _ripple2 = AnimationController(vsync: this, duration: 1500.ms)
      ..repeat(reverse: false);
    _ripple3 = AnimationController(vsync: this, duration: 1500.ms)
      ..repeat(reverse: false);

    // Stagger the rings
    Future.delayed(400.ms, () { if (mounted) _ripple2.forward(); });
    Future.delayed(800.ms, () { if (mounted) _ripple3.forward(); });
  }

  @override
  void dispose() {
    _ripple1.dispose();
    _ripple2.dispose();
    _ripple3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isRecording ? _recording : _primary;

    return GestureDetector(
      onLongPressStart: (_) => widget.onRecordStart(),
      onLongPressEnd: (_) => widget.onRecordStop(),
      // Also handle quick taps as a single record toggle (mobile-friendly)
      onTap: () {
        if (widget.isRecording) {
          widget.onRecordStop();
        } else {
          widget.onRecordStart();
        }
      },
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripple rings — only visible while recording
            if (widget.isRecording) ...[
              _RippleRing(controller: _ripple1, color: color, maxRadius: 110),
              _RippleRing(controller: _ripple2, color: color, maxRadius: 110),
              _RippleRing(controller: _ripple3, color: color, maxRadius: 110),
            ],

            // Outer glow circle
            AnimatedContainer(
              duration: 300.ms,
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
                border: Border.all(color: color.withOpacity(0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(widget.isRecording ? 0.5 : 0.2),
                    blurRadius: widget.isRecording ? 40 : 20,
                    spreadRadius: widget.isRecording ? 10 : 4,
                  ),
                ],
              ),
            ),

            // Inner button
            AnimatedContainer(
              duration: 200.ms,
              width: widget.isRecording ? 120 : 130,
              height: widget.isRecording ? 120 : 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color,
                    color.withOpacity(0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: widget.isRecording
                    ? const Icon(Icons.stop_rounded,
                        size: 52, color: Colors.white)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 600.ms)
                    : const Icon(Icons.mic_rounded,
                        size: 52, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single expanding + fading ring.
class _RippleRing extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double maxRadius;

  const _RippleRing({
    required this.controller,
    required this.color,
    required this.maxRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        return Container(
          width: maxRadius * 2 * t,
          height: maxRadius * 2 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity((1 - t) * 0.6),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}