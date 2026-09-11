# Android release signing

Google Play **rejects** app bundles signed with debug keys. Configure a release keystore before `flutter build appbundle --release`.

## 1. Create a keystore (one time)

```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Store the passwords safely (password manager or Play App Signing).

## 2. Configure Gradle

```bash
cp key.properties.example key.properties
# Edit key.properties with your passwords and paths
```

`android/app/build.gradle.kts` uses `android/key.properties` when present. Without it, `bundleRelease` fails; release APKs still sign with **debug** keys (local testing only).

## 3. Build for Play Store

```bash
make build-aab   # needs config/admob.json too — see config/admob.example.json
```

## Play App Signing

Play App Signing is on: Google holds the **app signing key** and re-signs every install from Play. You sign uploads with the **upload key** above. The two are different keys.

App signing certificate (`deployment_cert.der` from Play Console → Test and release → App integrity). It's public, so it's safe to record here:

| | |
|---|---|
| Subject | CN=Android, OU=Android, O=Google Inc. (Google-generated) |
| Key | RSA 4096, SHA256withRSA |
| Valid | 2026-05-21 → 2056-05-21 |
| SHA-1 | `74:0F:CA:29:B8:AF:85:CF:EC:58:EC:BB:F1:B8:AB:6B:05:C3:B9:C6` |
| SHA-256 | `8C:1D:FC:B1:3B:83:0F:B4:13:45:7C:6C:5E:07:B7:3F:C9:0A:EA:21:47:29:90:6A:9D:E0:01:D1:B9:BC:DC:54` |

LogicSprint doesn't need these fingerprints today: Supabase anonymous auth and AdMob don't check the signing key. You'll need them only if you add something that is tied to a signing key: Google Sign-In, a restricted Google API key, or Android App Links (`assetlinks.json`). Register the SHA-256 above there, plus the upload key's SHA-256 if you also test locally signed builds.

## Git safety

These files are **gitignored** and must never be committed:

- `android/key.properties`
- `android/*.jks`, `android/*.keystore`
- `config/admob.json`
