import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Optional Firebase bootstrap. Gameplay works when initialization fails.
abstract final class AppFirebaseService {
  static bool _initialized = false;

  static bool get isAvailable => _initialized;

  static Future<bool> initialize() async {
    if (_initialized) {
      return true;
    }
    if (!DefaultFirebaseOptions.isConfigured) {
      return false;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
      return true;
    } on Object {
      _initialized = false;
      return false;
    }
  }
}
