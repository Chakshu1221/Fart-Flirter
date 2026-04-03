/// Stub used on WEB only (imported when dart.library.html is present).
/// Provides empty Interpreter class so the code compiles on web.
/// The real tflite_flutter is used on Android/iOS via conditional import.
class Interpreter {
  static Future<Interpreter> fromAsset(String asset) async =>
      throw UnsupportedError('TFLite not supported on web');

  void run(Object input, Object output) =>
      throw UnsupportedError('TFLite not supported on web');

  void close() {}
}