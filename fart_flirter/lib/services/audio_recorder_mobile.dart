import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

/// Mobile (Android/iOS) audio recorder.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String _path = '';

  bool get isRecording => _isRecording;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (_isRecording) return;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/fart_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 128000,
      ),
      path: _path,
    );
    _isRecording = true;
  }

  Future<({String path, Uint8List pcmBytes})> stop() async {
    if (!_isRecording) throw StateError('stop() called before start()');
    final saved = await _recorder.stop() ?? _path;
    _isRecording = false;
    final wav = await File(saved).readAsBytes();
    // Strip 44-byte RIFF WAV header → raw int16 PCM
    final pcm = wav.length > 44 ? wav.sublist(44) : Uint8List(0);
    return (path: saved, pcmBytes: pcm);
  }

  Future<void> cancel() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }
  }

  Future<void> dispose() async {
    await cancel();
    _recorder.dispose();
  }
}