// File generated from Firebase client config (google-services.json / GoogleService-Info.plist).
// Project: logic-sprint
//
// Do NOT put Admin SDK service account keys here — use credentials/ for CLI only.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

abstract final class DefaultFirebaseOptions {
  static const String _projectId = 'logic-sprint';

  static bool get isConfigured => android.projectId == _projectId;

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
    apiKey: 'AIzaSyB8OIrOPVb9sGAAZ1ebPARV_l7n3jQ7saA',
    appId: '1:464131010897:android:0c8a8bf6ff96becebf6370',
    messagingSenderId: '464131010897',
    projectId: _projectId,
    storageBucket: 'logic-sprint.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCzuZSLSArYFYQRZ-mypEXwpQxf6WDqYOo',
    appId: '1:464131010897:ios:4b5c06ba30025ec2bf6370',
    messagingSenderId: '464131010897',
    projectId: _projectId,
    storageBucket: 'logic-sprint.firebasestorage.app',
    iosBundleId: 'com.logicsprint.logicSprint',
  );
}
