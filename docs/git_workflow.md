# Git Workflow — LogicSprint

## One branch

`production` is the main branch. Commit and push to it directly; CI (`.github/workflows/flutter_ci.yml`) runs `flutter analyze` and `flutter test` on every push.

```bash
git checkout production
git pull
# ... edit ...
make check
git add -A && git commit -m "Describe the change"
git push
```

## Store releases

Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2` — the number after `+` must increase for every Play upload), commit, then tag:

```bash
git tag -a v1.0.1 -m "LogicSprint v1.0.1"
git push origin v1.0.1
```

A `vX.Y.Z` tag runs `.github/workflows/release.yml`, which builds the signed APK and App Bundle and attaches them to a GitHub Release. It needs these repository secrets:

| Secret | Contents |
|--------|----------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i android/upload-keystore.jks` |
| `ANDROID_KEY_PROPERTIES` | contents of `android/key.properties` |
| `ADMOB_CONFIG_JSON` | contents of `config/admob.json` |

Preview tags (e.g. `v1.0.0-preview.1`) don't trigger the workflow; build those locally with `make build-apk`.
