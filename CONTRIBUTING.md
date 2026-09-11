# Contributing to LogicSprint

Work goes straight to `production`, the main branch — see [docs/git_workflow.md](docs/git_workflow.md).

```bash
make setup
make check    # same as CI: analyze + test
flutter run
```

### Pre-push checks (like Husky)

This repo uses **`.githooks/`** instead of Node/Husky — no extra runtime required.

One-time setup per clone:

```bash
make hooks-install
```

After that, every `git push` runs `make check` (`flutter analyze` + `flutter test`). Skip once if needed:

```bash
git push --no-verify
```
