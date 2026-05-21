# Git Workflow — LogicSprint

## Branches

| Branch | Role |
|--------|------|
| `main` | **Production** — store-ready releases only |
| `develop` | **Integration** — day-to-day work merges here |
| `feature/*` | Short-lived branches off `develop` |

## Day-to-day development

```bash
git checkout develop
git pull origin develop
git checkout -b feature/my-change
# ... edit, test ...
git add -A && git commit -m "Describe the change"
git push -u origin feature/my-change
```

Open a **Pull Request → `develop`**. CI runs `flutter analyze` and `flutter test`.

## Releasing to production

When `develop` is tested and ready for a store build:

```bash
git checkout develop
git pull origin develop
gh pr create --base main --head develop --title "Release v1.x.x"
```

After review, merge the PR into `main`, then tag:

```bash
git checkout main
git pull origin main
git tag -a v1.0.0 -m "LogicSprint v1.0.0"
git push origin v1.0.0
```

Build from `main`:

```bash
flutter build appbundle --release
flutter build ipa --release
```

## Hotfixes on production

```bash
git checkout main
git pull origin main
git checkout -b hotfix/critical-fix
# fix, test, commit
git push -u origin hotfix/critical-fix
```

PR: `hotfix/*` → `main`, then merge `main` back into `develop`.

## Rules

- Do not commit directly to `main` except via release/hotfix PRs.
- Keep `develop` up to date after every `main` release (merge `main` → `develop`).
- Run `flutter analyze` and `flutter test` before opening a PR.

## CI (GitHub Actions)

| Workflow | When | Purpose |
|----------|------|---------|
| [flutter_ci.yml](../.github/workflows/flutter_ci.yml) | Push/PR to `main` or `develop` | `flutter analyze` + `flutter test` |
| [pr_branch_policy.yml](../.github/workflows/pr_branch_policy.yml) | Pull requests | Enforces `feature/*` → `develop`, release/hotfix → `main` |

After your repo settings are approved, you can require these checks on `main` / `develop` under **Settings → Branches → Branch protection** (status contexts: `analyze-and-test`, `check-base-branch`).
