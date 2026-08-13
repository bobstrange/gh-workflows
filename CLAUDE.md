# gh-workflows

Shared CI (reusable workflow) and git hooks (lefthook remote config) consumed by my
other repositories via the moving `v1` tag. Changes here propagate to every consumer,
so treat every edit as a cross-repo change.

After cloning, run `lefthook install`: this repo dogfoods `lefthook/common.yml`
through a local `extends:` in `lefthook.yml`, so every commit here exercises the
shared hooks before any consumer refetches them.

## Release convention (required after every merged change)

1. Merge to `main` (CI must be green — this repo consumes its own lint workflow)
2. Run `make release` (defaults to a patch bump; `make release BUMP=minor` for new
   features, `BUMP=major` for breaking changes). The script tags `v1.x.y`, force-moves
   the major tag to it, and pushes both — never move `v1` by hand

A merged change that is not tagged reaches nobody: consumers only follow `v1`.
Breaking changes (removing a linter, renaming the job, changing required inputs) go to
`v2.0.0` — consumers stay on `v1` until they opt in.

## Consumer contract (do not break within v1)

- Workflow path `.github/workflows/lint.yml`, callable with **zero required inputs**. New
  inputs stay optional and default to the current behavior, so the zero-input call never
  changes meaning
- Job name `lint` (consumers' required-status-check rulesets reference it as
  `lint / lint`)
- Repo-local pins (`package.json` + **npm** lockfile) win over the inline fallback
  pins. npm only: pnpm/yarn repos silently get the fallback pins instead
- Consumer configs win over the built-in fallbacks: yamllint / markdownlint fall back
  to a relaxed 120-column config only when the repo has none
- A consumer with its own `.secretlintrc.json` must also pin `secretlint` and every
  referenced rule in its `package.json` — the npx fallback installs only the
  recommend preset
- Hook names in `lefthook/common.yml` keep their `common-` prefix (collision-safety
  with consumer configs); hooks are never stricter than CI (markdownlint / yamllint
  hooks stay inactive in repos without a config)
- All `uses:` are SHA-pinned with a trailing version comment — never re-point them to
  a mutable tag; checkout keeps `persist-credentials: false`

## Version pins

This repo's own `package.json` pins are Dependabot-managed and dogfood the
workflow's npm path. The **inline** fallback pins are not: prettier / secretlint /
yamllint in `lint.yml` (`env:` block) and prettier / secretlint / markdownlint-cli2
in `lefthook/common.yml` must be bumped manually — keep them in step when
Dependabot moves `package.json`.
