# gh-workflows

Shared CI and git-hook layer for bobstrange's repositories. The contents live here;
consumer repos hold only a few-line stub pointing at the moving `v1` tag, so improvements
land everywhere without touching each repo.

## What's inside

- `.github/workflows/lint.yml` — reusable lint workflow (`workflow_call`): prettier,
  secretlint, shellcheck, yamllint, markdownlint, actionlint as serial steps in one job
  (one billed minute per run), each under `!cancelled()` so one failure never hides the rest
- `lefthook/common.yml` — the matching pre-commit hooks, consumed via lefthook `remotes:`

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

- Version pins: a repo-local pin (`package.json` + lockfile) always wins; the inline
  pins here are fallbacks for repos without one
- secretlint uses the repo's `.secretlintrc.json` when present, otherwise the
  recommend preset
- Repo-specific jobs (tests, language toolchains) stay in each repo's own workflow,
  next to the caller job — see the escape hatches below

## When a repo outgrows this

1. Tune: add repo-local jobs alongside the `uses:` caller
2. Pin: stay on an old tag while others move forward
3. Graduate: replace the one `uses:` line with a bespoke workflow — no other repo is
   affected
