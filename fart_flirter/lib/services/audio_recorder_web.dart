import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

/// Web audio recorder — streams raw PCM into memory (no filesystem).
/// The browser handles mic permission via getUserMedia automatically.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  StreamSubscription<Uint8List>? _sub;
  final List<int> _buf = [];

  bool get isRecording => _isRecording;

  Future<bool> hasPermission() async => true; // browser handles this

  Future<void> start() async {
    if (_isRecording) return;
    _buf.clear();

    final stream = await _recorder.startStream(
      // NOTE: No 'const' here — RecordConfig has no const constructor
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      ),
    );
    _sub = stream.listen(_buf.addAll);
    _isRecording = true;
  }

  Future<({String path, Uint8List pcmBytes})> stop() async {
    if (!_isRecording) throw StateError('stop() called before start()');
    await _recorder.stop();
    await _sub?.cancel();
    _sub = null;
    _isRecording = false;
    // Stream gives raw int16 PCM — no WAV header to strip
    final pcm = Uint8List.fromList(_buf);
    _buf.clear();
    return (path: 'web_stream', pcmBytes: pcm);
  }

  Future<void> cancel() async {
    if (_isRecording) {
      await _recorder.stop();
      await _sub?.cancel();
      _sub = null;
      _buf.clear();
      _isRecording = false;
    }
  }

  Future<void> dispose() async {
    await cancel();
    _recorder.dispose();
  }
}