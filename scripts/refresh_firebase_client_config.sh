#!/usr/bin/env bash
# Download fresh Firebase CLIENT config using Admin SDK JSON in credentials/.
# Does NOT rotate API keys — rotate in Google Cloud Console first, then run this.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRED="${GOOGLE_APPLICATION_CREDENTIALS:-$ROOT/credentials/logic-sprint-firebase.json}"
PROJECT="${FIREBASE_PROJECT:-logic-sprint}"

if [[ ! -f "$CRED" ]]; then
  echo "Missing: $CRED"
  echo "Place your Firebase Admin SDK JSON under credentials/ (gitignored)."
  exit 1
fi

export GOOGLE_APPLICATION_CREDENTIALS="$CRED"

echo "Fetching Android google-services.json ..."
firebase apps:sdkconfig ANDROID --project "$PROJECT" > "$ROOT/android/app/google-services.json"

echo "Fetching iOS GoogleService-Info.plist ..."
firebase apps:sdkconfig IOS --project "$PROJECT" > "$ROOT/ios/Runner/GoogleService-Info.plist"

python3 "$ROOT/scripts/firebase_options_from_google_services.py"

echo "Done. Updated (gitignored):"
echo "  android/app/google-services.json"
echo "  ios/Runner/GoogleService-Info.plist"
echo "  lib/firebase_options.dart"
