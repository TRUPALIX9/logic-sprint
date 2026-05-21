# Git Workflow — LogicSprint

## Branches

| Branch | Role |
|--------|------|
| `production` | **Production** — store-ready releases only |
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
gh pr create --base production --head develop --title "Release v1.x.x"
```

After review, merge the PR into `production`, then tag:

```bash
git checkout production
git pull origin production
git tag -a v1.0.0 -m "LogicSprint v1.0.0"
git push origin v1.0.0
```

Build from `production`:

```bash
flutter build appbundle --release
flutter build ipa --release
```

## Hotfixes on production

```bash
git checkout production
git pull origin production
git checkout -b hotfix/critical-fix
# fix, test, commit
git push -u origin hotfix/critical-fix
```

PR: `hotfix/*` → `production`, then merge `production` back into `develop`.

## Rules

- Do not commit directly to `production` except via release/hotfix PRs.
- Keep `develop` up to date after every production release (merge `production` → `develop`).
- Run `flutter analyze` and `flutter test` before opening a PR.

## CI (GitHub Actions)

| Workflow | When | Purpose |
|----------|------|---------|
| [flutter_ci.yml](../.github/workflows/flutter_ci.yml) | Push/PR to `production` or `develop` | `flutter analyze` + `flutter test` |
| [pr_branch_policy.yml](../.github/workflows/pr_branch_policy.yml) | Pull requests | Enforces `feature/*` → `develop`, release/hotfix → `production` |

After your repo settings are approved, you can require these checks on `production` / `develop` under **Settings → Branches → Branch protection** (status contexts: `analyze-and-test`, `check-base-branch`).
