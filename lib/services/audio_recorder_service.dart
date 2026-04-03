// Dispatcher: exports the correct implementation based on the platform.
//   dart.library.html  → available on WEB   → use web implementation
//   dart.library.io    → available on MOBILE → use mobile implementation
export 'audio_recorder_mobile.dart'
    if (dart.library.html) 'audio_recorder_web.dart';