import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/fart_result.dart';
import '../services/audio_processor.dart';
import '../services/audio_recorder_service.dart';
import '../services/fart_classifier_service.dart';
import '../services/scoring_service.dart';
import '../utils/audio_utils.dart';
import '../widgets/record_button.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _recorder   = AudioRecorderService();
  final _classifier = FartClassifierService();

  bool _isRecording  = false;
  bool _isProcessing = false;
  bool _modelReady   = false;
  String _statusText = 'Loading…';

  static const _green  = Color(0xFF7FFF00);
  static const _yellow = Color(0xFFFFDD00);
  static const _bg     = Color(0xFF0A0A0F);

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      await _classifier.init();
      if (mounted) setState(() {
        _modelReady  = true;
        _statusText  = kIsWeb
            ? '🌐 Web mode — tap & hold to record 💨'
            : 'Hold the button and let it rip 💨';
      });
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Init error: $e');
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _classifier.dispose();
    super.dispose();
  }

  // ── Permission ──────────────────────────────────────────────────────────────

  Future<bool> _checkMic() async {
    // On web the browser asks for mic permission automatically
    if (kIsWeb) return true;

    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final result = await Permission.microphone.request();
    if (result.isGranted) return true;

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF111118),
          title: Text('Microphone Needed',
              style: GoogleFonts.bangers(color: _green, fontSize: 22)),
          content: const Text('Grant mic permission to detect farts.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); openAppSettings(); },
              child: Text('Settings', style: TextStyle(color: _green)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      );
    }
    return false;
  }

  // ── Recording ───────────────────────────────────────────────────────────────

  Future<void> _onRecordStart() async {
    if (!_modelReady || _isProcessing) return;
    if (!await _checkMic()) return;
    await _recorder.start();
    if (mounted) setState(() {
      _isRecording = true;
      _statusText  = '🎙️ Recording… release to analyse';
    });
  }

  Future<void> _onRecordStop() async {
    if (!_isRecording) return;
    setState(() { _isRecording = false; _isProcessing = true; _statusText = '🔬 Analysing…'; });

    try {
      final (:path, :pcmBytes) = await _recorder.stop();

      final mfcc      = AudioProcessor.extractMfcc(pcmBytes);
      final (:isFart, :confidence) = _classifier.classify(mfcc);
      final rmsDb     = AudioUtils.pcmBytesToDb(pcmBytes);
      final duration  = AudioUtils.durationMs(pcmBytes.length);

      final result = ScoringService.evaluate(
        isFart: isFart, confidence: confidence,
        rmsDb: rmsDb, durationMs: duration,
      );

      if (mounted) {
        Navigator.push(context, PageRouteBuilder(
          pageBuilder: (_, a, __) => ResultScreen(result: result),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: 400.ms,
        )).then((_) {
          if (mounted) setState(() {
            _isProcessing = false;
            _statusText = kIsWeb
                ? '🌐 Web mode — tap & hold to record 💨'
                : 'Hold the button and let it rip 💨';
          });
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isProcessing = false; _statusText = 'Error: $e'; });
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          if (kIsWeb) _buildWebBadge(),
          const Spacer(),
          _isProcessing ? _buildLoader() : RecordButton(
            isRecording: _isRecording,
            onRecordStart: _onRecordStart,
            onRecordStop: _onRecordStop,
          ).animate().scale(delay: 400.ms, duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: 300.ms,
            child: Text(_statusText, key: ValueKey(_statusText),
              textAlign: TextAlign.center,
              style: GoogleFonts.bangers(
                fontSize: 20, letterSpacing: 1,
                color: _isRecording ? const Color(0xFFFF3C3C) : Colors.white54,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Text('TAP or HOLD to record • Release to analyse',
              style: TextStyle(color: Colors.white.withOpacity(0.15),
                  fontSize: 12, letterSpacing: 1.5)),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(children: [
        const Text('💨', style: TextStyle(fontSize: 56))
            .animate().fadeIn(duration: 600.ms).moveY(begin: -20),
        const SizedBox(height: 8),
        Text('FART FLIRTER', style: GoogleFonts.bangers(
          fontSize: 42, letterSpacing: 4,
          foreground: Paint()..shader = const LinearGradient(
              colors: [_green, _yellow])
              .createShader(const Rect.fromLTWH(0, 0, 280, 50)),
        )).animate().fadeIn(duration: 700.ms, delay: 100.ms),
        Text('ANALYZER', style: GoogleFonts.bangers(
            fontSize: 22, letterSpacing: 8, color: Colors.white30))
            .animate().fadeIn(duration: 700.ms, delay: 200.ms),
      ]),
    );
  }

  Widget _buildWebBadge() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.4)),
      ),
      child: const Text('🌐 Web Mode — Rule-Based Scoring',
        style: TextStyle(color: Colors.blue, fontSize: 11, letterSpacing: 1)),
    );
  }

  Widget _buildLoader() {
    return SizedBox(width: 220, height: 220, child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: _green, strokeWidth: 3),
        const SizedBox(height: 20),
        Text('Analysing…', style: GoogleFonts.bangers(color: _green, fontSize: 22)),
      ]),
    ));
  }
}