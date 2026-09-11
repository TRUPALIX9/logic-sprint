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

App signing certificates for `com.trupal.logicsprint`, downloaded from Play Console → Test and release → App integrity. Google generated all three on 2026-09-11 and holds the keys. They're public, so they're safe to record here:

| File | What it is | Key | SHA-256 |
|---|---|---|---|
| `deployment_cert.der` | The key installs are signed with today | RSA 4096 | `BE:D7:F9:A9:8E:81:3E:B7:A9:AF:2B:A0:DA:52:70:48:6C:F8:0F:B7:02:B7:5D:3C:22:15:A2:C2:EB:D7:30:F6` |
| `hybrid_classical_cert.der` | Classic half of Google's hybrid (post-quantum) signing | RSA 4096 | `35:EE:20:54:B1:D4:0F:FE:A4:F3:CD:DA:8B:FF:A1:C0:5D:7E:9A:C4:DD:15:A8:7B:0F:D3:90:BA:9C:96:A0:82` |
| `hybrid_pqc_cert.der` | Post-quantum half, for Android versions that check quantum-safe signatures | ML-DSA-65 | `F0:FC:3E:1A:10:0F:5C:BE:98:A4:A1:A9:1F:55:EC:E6:AC:68:9B:CA:36:10:C9:34:24:4D:15:28:A9:61:AE:F3` |

`deployment_cert.der` SHA-1: `E4:B3:BB:62:D4:66:09:87:AA:DE:60:DC:CC:FD:2C:CF:10:F4:66:D8`. All three are valid until 2056-09-11. An earlier certificate dated 2026-05-21 (SHA-256 `8C:1D:…:DC:54`) is replaced by these.

Upload key certificate (`android/upload-keystore.jks`, alias `upload`, created 2026-09-11). This is yours, not Google's. Play Console → App integrity → Upload key certificate should show the same SHA-256 once the first bundle is uploaded:

| | |
|---|---|
| Owner | CN=Trupal Patel, O=LogicSprint |
| Valid | 2026-09-11 → 2054-01-27 |
| SHA-256 | `66:7F:D0:48:FD:F5:B1:28:93:8C:30:8C:5E:B0:6A:C5:0D:36:97:03:94:EE:61:53:D6:C6:C8:6B:F5:F9:C4:04` |

LogicSprint doesn't need these fingerprints today: Supabase anonymous auth and AdMob don't check the signing key. You'll need them only if you add something that is tied to a signing key: Google Sign-In, a restricted Google API key, or Android App Links (`assetlinks.json`). Register the SHA-256 above there, plus the upload key's SHA-256 if you also test locally signed builds.

## Git safety

These files are **gitignored** and must never be committed:

- `android/key.properties`
- `android/*.jks`, `android/*.keystore`
- `config/admob.json`
