# gh-workflows

Shared CI and git-hook layer for bobstrange's repositories. Nearly all of it lives here
and consumer repos hold only a few-line stub pointing at the moving `v1` tag, so
improvements land everywhere without touching each repo. The exception is
`.github/dependabot.yml`: Dependabot reads it only from a repo's own root, so that one
is a real file everywhere and this README carries the convention for it.

## What's inside

- `.github/workflows/lint.yml` — reusable lint workflow (`workflow_call`): prettier,
  secretlint, shellcheck, yamllint, markdownlint, actionlint as serial steps in one job
  (one billed minute per run), each under `!cancelled()` so one failure never hides the rest
- `lefthook/common.yml` — pre-commit hooks for the same linters, consumed via lefthook
  `remotes:`. Hooks are best-effort and never stricter than CI: shellcheck / yamllint
  skip on machines without the tool, markdownlint / yamllint stay inactive in repos
  without their config; CI is always the backstop. shellcheck takes `*.sh` / `*.bash`
  plus extensionless executables whose shebang names a shell, mirroring how CI finds
  scripts — a deliberate subset, since a hook cannot honour `shellcheck_ignore_paths`

## Usage

Three files go into a consumer repo — two stubs pointing here and one real file —
plus a branch ruleset that makes the CI actually block anything.

### CI

`.github/workflows/lint.yml`:

```yaml
---
name: Lint

on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  lint:
    uses: bobstrange/gh-workflows/.github/workflows/lint.yml@v1
```

#### Inputs

All optional — the zero-input call above stays valid.

| Input                     | Default | Effect                                                                                                                                                                                        |
| ------------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `shellcheck_ignore_paths` | `""`    | Space-separated paths shellcheck skips, on top of `node_modules`. For shell-adjacent files it cannot parse (zsh config, templated scripts)                                                    |
| `markdownlint_enabled`    | `true`  | Set to `false` to skip markdownlint entirely. For repos whose markdown is machine-written and structurally violates style rules — the same repos typically ignore `*.md` in `.prettierignore` |

### Hooks

`lefthook.yml` (then `lefthook install`):

```yaml
remotes:
  - git_url: https://github.com/bobstrange/gh-workflows
    ref: v1
    refetch_frequency: 24h
    configs:
      - lefthook/common.yml
```

### Dependency updates

`.github/dependabot.yml`. The `github-actions` entry below is **required in every
consumer**: `v1` keeps the linter pins and the actions inside `lint.yml` current, but
nothing covers the actions a repo pins in its own workflows.

```yaml
---
version: 2
updates:
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
    commit-message:
      prefix: "chore(ci)"
    # Wait out the window in which a compromised action release is typically
    # discovered and yanked before proposing it.
    cooldown:
      default-days: 7
    # One reviewable PR per week instead of a stream of individual bumps.
    groups:
      actions-minor:
        update-types: [minor, patch]
```

Every other ecosystem is **optional and per-repo** — add `uv`, `npm`, `pip` and the
like only where that repo actually manages such dependencies. Whatever is added keeps
the same weekly schedule, 7-day `cooldown` and minor/patch grouping, with a
`chore(deps)` prefix.

### Required status check

Without this the shared workflow runs and reports, but a red run merges anyway. Protect
the default branch with a ruleset requiring the check by the name **`lint / lint`** —
the consumer's caller job, then this repo's job inside it. Any other spelling silently
never matches: the check stays `expected` and the PR waits on it forever.

```sh
gh api repos/OWNER/REPO/rulesets --method POST --input - <<'JSON'
{
  "name": "protect-main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "allowed_merge_methods": ["merge", "squash", "rebase"]
    } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [{ "context": "lint / lint", "integration_id": 15368 }]
    } }
  ]
}
JSON
```

Repos with jobs of their own add each one's name to `required_status_checks` alongside
`lint / lint`. Rulesets are the standard here — the older branch-protection API can
express the same thing, but keeping one mechanism means one place to look when a merge
is unexpectedly allowed or blocked.

## Versioning

`v1` is a moving major tag (like action tags): backward-compatible changes move it
forward, breaking changes go to `v2`. Consumers on `@v1` / `ref: v1` follow
automatically — CI immediately, hooks within `refetch_frequency`.

## Conventions baked in

- Version pins: a repo-local pin (`package.json` + **npm** lockfile) wins; the inline
  pins here are fallbacks for repos without one (pnpm/yarn repos get the fallbacks)
- Lint configs: the repo's own yamllint / markdownlint / secretlint configs win;
  without them, relaxed 120-column fallbacks (and the secretlint recommend preset)
  apply. A custom `.secretlintrc.json` requires pinning secretlint and its rules in
  `package.json`
- Repo-specific jobs (tests, language toolchains) stay in each repo's own workflow,
  next to the caller job — see the escape hatches below

## When a repo outgrows this

1. Tune: add repo-local jobs alongside the `uses:` caller
2. Pin: stay on an old tag while others move forward
3. Graduate: replace the one `uses:` line with a bespoke workflow — no other repo is
   affected
