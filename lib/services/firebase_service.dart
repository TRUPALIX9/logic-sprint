import 'package:firebase_core/firebase_core.dart';

/// Optional Firebase bootstrap — works gracefully when no options are provided.
/// firebase_options.dart is no longer bundled in this project; Firebase init
/// is skipped at runtime but kept here so existing call-sites in main.dart
/// continue to compile.
abstract final class AppFirebaseService {
  static bool _initialized = false;

  static bool get isAvailable => _initialized;

  static Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      // Firebase.app() throws if no default app exists yet; use that to check
      // whether options were already supplied (e.g. via a future native layer).
      Firebase.app();
      _initialized = true;
      return true;
    } on FirebaseException {
      // No google-services.json / GoogleService-Info.plist at runtime.
      // The app works fine without Firebase; Supabase handles the leaderboard.
      _initialized = false;
      return false;
    } on Object {
      _initialized = false;
      return false;
    }
  }
}
