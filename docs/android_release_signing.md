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

## Git safety

These files are **gitignored** and must never be committed:

- `android/key.properties`
- `android/*.jks`, `android/*.keystore`
- `config/admob.json`
