#!/usr/bin/env python3
"""Generate lib/firebase_options.dart from local google-services.json + plist."""
from __future__ import annotations

import json
import plistlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID_JSON = ROOT / "android/app/google-services.json"
IOS_PLIST = ROOT / "ios/Runner/GoogleService-Info.plist"
OUT = ROOT / "lib/firebase_options.dart"


def main() -> None:
    if not ANDROID_JSON.is_file():
        raise SystemExit(f"Missing {ANDROID_JSON}")

    android = json.loads(ANDROID_JSON.read_text())
    client = android["client"][0]
    project_info = android["project_info"]
    api_key = client["api_key"][0]["current_key"]
    app_id = client["client_info"]["mobilesdk_app_id"]
    sender = project_info["project_number"]
    project_id = project_info["project_id"]
    bucket = project_info["storage_bucket"]

    ios_key = "REPLACE_IOS_API_KEY"
    ios_app = "REPLACE_IOS_APP_ID"
    bundle = "com.logicsprint.logicSprint"
    if IOS_PLIST.is_file():
        plist = plistlib.loads(IOS_PLIST.read_bytes())
        ios_key = plist.get("API_KEY", ios_key)
        ios_app = plist.get("GOOGLE_APP_ID", ios_app)
        bundle = plist.get("BUNDLE_ID", bundle)

    dart = f'''// Generated locally — do not commit (gitignored).
// Regenerate: ./scripts/refresh_firebase_client_config.sh

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

abstract final class DefaultFirebaseOptions {{
  static const String _projectId = '{project_id}';

  static bool get isConfigured {{
    const key = android.apiKey;
    return key.isNotEmpty &&
        !key.startsWith('REPLACE_') &&
        android.projectId == _projectId;
  }}

  static FirebaseOptions get currentPlatform {{
    if (kIsWeb) {{
      throw UnsupportedError('LogicSprint does not target web.');
    }}
    switch (defaultTargetPlatform) {{
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }}
  }}

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '{api_key}',
    appId: '{app_id}',
    messagingSenderId: '{sender}',
    projectId: _projectId,
    storageBucket: '{bucket}',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '{ios_key}',
    appId: '{ios_app}',
    messagingSenderId: '{sender}',
    projectId: _projectId,
    storageBucket: '{bucket}',
    iosBundleId: '{bundle}',
  );
}}
'''
    OUT.write_text(dart)
    if "REPLACE_" in api_key:
        print("Warning: Android API key still looks like a placeholder.")


if __name__ == "__main__":
    main()
