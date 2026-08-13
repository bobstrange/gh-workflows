# gh-workflows

Shared CI and git-hook layer for bobstrange's repositories. The contents live here;
consumer repos hold only a few-line stub pointing at the moving `v1` tag, so improvements
land everywhere without touching each repo.

## What's inside

- `.github/workflows/lint.yml` — reusable lint workflow (`workflow_call`): prettier,
  secretlint, shellcheck, yamllint, markdownlint, actionlint as serial steps in one job
  (one billed minute per run), each under `!cancelled()` so one failure never hides the rest
- `lefthook/common.yml` — pre-commit hooks for the same linters, consumed via lefthook
  `remotes:`. Hooks are best-effort and never stricter than CI: shellcheck / yamllint
  skip on machines without the tool, markdownlint / yamllint stay inactive in repos
  without their config; CI is always the backstop

## Usage

CI — `.github/workflows/lint.yml` in the consumer repo:

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

### Inputs

All optional — the zero-input call above stays valid.

| Input                     | Default | Effect                                                                                                                                     |
| ------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `shellcheck_ignore_paths` | `""`    | Space-separated paths shellcheck skips, on top of `node_modules`. For shell-adjacent files it cannot parse (zsh config, templated scripts) |

Hooks — `lefthook.yml` in the consumer repo (then `lefthook install`):

```yaml
remotes:
  - git_url: https://github.com/bobstrange/gh-workflows
    ref: v1
    refetch_frequency: 24h
    configs:
      - lefthook/common.yml
```

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
