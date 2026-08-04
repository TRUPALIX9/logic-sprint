// Safe placeholder for analysis and CI. Replace locally via:
//   ./scripts/refresh_firebase_client_config.sh
// Do not commit real API keys.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

abstract final class DefaultFirebaseOptions {
  static const String _projectId = 'logic-sprint';

  static bool get isConfigured {
    return android.apiKey.isNotEmpty &&
        !android.apiKey.startsWith('REPLACE_') &&
        android.projectId == _projectId;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('LogicSprint does not target web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ANDROID_API_KEY',
    appId: 'REPLACE_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_SENDER_ID',
    projectId: _projectId,
    storageBucket: 'logic-sprint.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_IOS_API_KEY',
    appId: 'REPLACE_IOS_APP_ID',
    messagingSenderId: 'REPLACE_SENDER_ID',
    projectId: _projectId,
    storageBucket: 'logic-sprint.firebasestorage.app',
    iosBundleId: 'com.trupal.logicsprint',
  );
}
