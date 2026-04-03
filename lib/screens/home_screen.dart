import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  bool   _isRecording  = false;
  bool   _isProcessing = false;
  bool   _modelReady   = false;
  String _statusText   = 'Loading model…';

  static const _green  = Color(0xFF7FFF00);
  static const _yellow = Color(0xFFFFDD00);
  static const _red    = Color(0xFFFF4444);
  static const _bg     = Color(0xFF0A0A0F);

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      await _classifier.init();
      if (mounted) {
        setState(() {
          _modelReady = true;
          _statusText = kIsWeb
              ? 'Web mode active 🌐  Tap & hold to record'
              : 'Hold the button and let it rip 💨';
        });
      }
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

  Future<bool> _checkMic() async {
    if (kIsWeb) return true; // browser popup handles it
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    if (result.isGranted) return true;

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF111118),
          title: const Text('Mic Permission Needed',
              style: TextStyle(color: _green, fontSize: 20, fontWeight: FontWeight.bold)),
          content: const Text('Grant microphone access to detect farts.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); openAppSettings(); },
              child: const Text('Open Settings', style: TextStyle(color: _green)),
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

  Future<void> _onRecordStart() async {
    if (!_modelReady || _isProcessing) return;
    if (!await _checkMic()) return;
    await _recorder.start();
    if (mounted) setState(() {
      _isRecording = true;
      _statusText  = '🎙️  Recording… release to analyse';
    });
  }

  Future<void> _onRecordStop() async {
    if (!_isRecording) return;
    setState(() {
      _isRecording  = false;
      _isProcessing = true;
      _statusText   = '🔬  Analysing…';
    });

    try {
      final (:path, :pcmBytes) = await _recorder.stop();
      final mfcc             = AudioProcessor.extractMfcc(pcmBytes);
      final (:isFart, :confidence) = _classifier.classify(mfcc);
      final rmsDb            = AudioUtils.pcmBytesToDb(pcmBytes);
      final duration         = AudioUtils.durationMs(pcmBytes.length);

      final result = ScoringService.evaluate(
        isFart: isFart, confidence: confidence,
        rmsDb: rmsDb,   durationMs: duration,
      );

      if (mounted) {
        await Navigator.push(context,
          MaterialPageRoute(builder: (_) => ResultScreen(result: result)));
        if (mounted) setState(() {
          _isProcessing = false;
          _statusText   = kIsWeb
              ? 'Web mode active 🌐  Tap & hold to record'
              : 'Hold the button and let it rip 💨';
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _isProcessing = false;
        _statusText   = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            const SizedBox(height: 40),
            const Text('💨', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_green, _yellow],
              ).createShader(bounds),
              child: const Text(
                'FART FLIRTER',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white, // ShaderMask overrides this
                  letterSpacing: 4,
                ),
              ),
            ),
            const Text(
              'ANALYZER',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white30,
                letterSpacing: 8,
              ),
            ),

            // Web badge
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.withOpacity(0.5)),
                ),
                child: const Text(
                  '🌐  Web Mode — Rule-Based Scoring',
                  style: TextStyle(color: Colors.blueAccent, fontSize: 12),
                ),
              ),
            ],

            // ── Record area ─────────────────────────────────────────────────
            const Spacer(),
            if (_isProcessing)
              const Column(
                children: [
                  CircularProgressIndicator(color: _green, strokeWidth: 3),
                  SizedBox(height: 20),
                  Text('Analysing…',
                      style: TextStyle(
                          color: _green, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              )
            else
              RecordButton(
                isRecording: _isRecording,
                onRecordStart: _onRecordStart,
                onRecordStop: _onRecordStop,
              ),

            const SizedBox(height: 32),

            // Status text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _isRecording ? _red : Colors.white60,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const Spacer(),

            // Hint
            const Padding(
              padding: EdgeInsets.only(bottom: 28),
              child: Text(
                'TAP or HOLD  •  Release to analyse',
                style: TextStyle(color: Colors.white24, fontSize: 12, letterSpacing: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}