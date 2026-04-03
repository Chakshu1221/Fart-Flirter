import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hold-to-record button with animated ripple rings.
/// Uses only core Flutter animation — no external packages needed.
class RecordButton extends StatefulWidget {
  final VoidCallback onRecordStart;
  final VoidCallback onRecordStop;
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
  late final List<AnimationController> _rippleControllers;
  late final List<Animation<double>>   _rippleAnims;

  static const _activeColor   = Color(0xFFFF4444); // red when recording
  static const _inactiveColor = Color(0xFF7FFF00); // green when idle

  @override
  void initState() {
    super.initState();

    // Three staggered ripple rings
    _rippleControllers = List.generate(3, (i) =>
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1800),
        ));

    _rippleAnims = _rippleControllers.map((c) =>
        CurvedAnimation(parent: c, curve: Curves.easeOut)).toList();

    // Stagger starts: 0ms, 600ms, 1200ms
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 600), () {
        if (mounted) _rippleControllers[i].repeat();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _rippleControllers) c.dispose();
    super.dispose();
  }

  Color get _color =>
      widget.isRecording ? _activeColor : _inactiveColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => widget.onRecordStart(),
      onLongPressEnd:   (_) => widget.onRecordStop(),
      onTap: () => widget.isRecording
          ? widget.onRecordStop()
          : widget.onRecordStart(),
      child: SizedBox(
        width: 220, height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ripple rings
            if (widget.isRecording)
              ...List.generate(3, (i) => AnimatedBuilder(
                animation: _rippleAnims[i],
                builder: (_, __) {
                  final t = _rippleAnims[i].value;
                  return Container(
                    width:  110 * 2 * t,
                    height: 110 * 2 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color.withOpacity((1 - t) * 0.6),
                        width: 2,
                      ),
                    ),
                  );
                },
              )),

            // Outer glow ring
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _color.withOpacity(0.12),
                border: Border.all(color: _color.withOpacity(0.35), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _color.withOpacity(widget.isRecording ? 0.5 : 0.2),
                    blurRadius: widget.isRecording ? 40 : 20,
                    spreadRadius: widget.isRecording ? 10 : 4,
                  ),
                ],
              ),
            ),

            // Inner button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:  widget.isRecording ? 118 : 128,
              height: widget.isRecording ? 118 : 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_color, _color.withOpacity(0.65)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _color.withOpacity(0.55),
                    blurRadius: 24, spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: widget.isRecording
                    ? const _PulsingIcon(icon: Icons.stop_rounded,  color: Colors.white)
                    : const Icon(Icons.mic_rounded, size: 52, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stop icon that pulses while recording.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.2)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Icon(widget.icon, size: 52, color: widget.color),
  );
}