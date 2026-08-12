# gh-workflows

Shared CI (reusable workflow) and git hooks (lefthook remote config) consumed by my
other repositories via the moving `v1` tag. Changes here propagate to every consumer,
so treat every edit as a cross-repo change.

## Release convention (required after every merged change)

1. Merge to `main` (CI must be green — this repo consumes its own lint workflow)
2. Create and push the next semver tag: `git tag v1.x.y && git push origin v1.x.y`
3. The `Move major tag` workflow then force-moves `v1` to that commit automatically —
   never move `v1` by hand

A merged change that is not tagged reaches nobody: consumers only follow `v1`.
Breaking changes (removing a linter, renaming the job, changing required inputs) go to
`v2.0.0` — consumers stay on `v1` until they opt in.

## Consumer contract (do not break within v1)

- Workflow path `.github/workflows/lint.yml`, callable with **zero required inputs**
- Job name `lint` (consumers' required-status-check rulesets reference it as
  `lint / lint`)
- Repo-local pins (`package.json` + lockfile) always win over the inline fallback pins
- Hook names in `lefthook/common.yml` keep their `common-` prefix (collision-safety
  with consumer configs)

## Version pins

The inline fallback pins (prettier, secretlint in both `lint.yml` and
`lefthook/common.yml`) are not covered by Dependabot — bump them manually when
consumer repos' package.json pins move ahead.
