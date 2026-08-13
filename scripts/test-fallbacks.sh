#!/usr/bin/env bash
set -euo pipefail

# Exercises lint.yml's fallback branches (no repo config, no package.json)
# against a bare fixture directory. This repo's own dogfood lint job carries
# every config, so without this test the fallback code only ever runs inside
# consumer repos — after v1 has already moved. The run blocks are extracted
# from the workflow with yq at test time, so the tested code is the shipped
# code, not a copy that can drift.
#
# Covered: yamllint fallback config, markdownlint config choice (both
# branches), prettier npx fallback, secretlint npx fallback. The steps
# that are marketplace actions (shellcheck, markdownlint, actionlint)
# are not runnable outside GitHub and stay out of scope.

wf="$(git rev-parse --show-toplevel)/.github/workflows/lint.yml"

for tool in yq pipx npx; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is required (preinstalled on GitHub runners)" >&2
    exit 1
  fi
done

step() { # <name> — the step's run block, exactly as shipped
  yq ".jobs.lint.steps[] | select(.name == \"$1\") | .run" "$wf"
}

run_step() { bash -euo pipefail -c "$(step "$1")"; }

expect_fail() { # <label> <step name>
  if run_step "$2" >/dev/null 2>&1; then
    echo "FAIL: $1 — step '$2' passed but should have failed" >&2
    exit 1
  fi
}

# Env pins exactly as the workflow defines them
PRETTIER_VERSION="$(yq '.jobs.lint.env.PRETTIER_VERSION' "$wf")"
SECRETLINT_VERSION="$(yq '.jobs.lint.env.SECRETLINT_VERSION' "$wf")"
YAMLLINT_VERSION="$(yq '.jobs.lint.env.YAMLLINT_VERSION' "$wf")"
export PRETTIER_VERSION SECRETLINT_VERSION YAMLLINT_VERSION

fixture="$(mktemp -d)"
# Like in real CI, RUNNER_TEMP lives outside the linted workspace
RUNNER_TEMP="$(mktemp -d)"
trap 'rm -rf "$fixture" "$RUNNER_TEMP"' EXIT
cd "$fixture"

GITHUB_OUTPUT="$RUNNER_TEMP/github-output"
export RUNNER_TEMP GITHUB_OUTPUT

# A minimal clean consumer: no lint configs, no package.json
printf '# fixture\n\nSome text.\n' > README.md
printf 'key: value\n' > config.yml
printf '{ "a": 1 }\n' > data.json

echo "== yamllint: fallback config passes a clean fixture"
run_step yamllint

echo "== yamllint: fallback config still flags long lines"
printf 'x: "%s"\n' "$(printf 'a%.0s' $(seq 150))" > long-line.yml
expect_fail "over-120-column line" yamllint
rm long-line.yml

echo "== markdownlint: no repo config generates the relaxed fallback"
: > "$GITHUB_OUTPUT"
run_step "Choose markdownlint config"
mdconfig="$(sed -n 's/^path=//p' "$GITHUB_OUTPUT" | tail -1)"
[ -n "$mdconfig" ] && [ -f "$mdconfig" ]
[ "$(yq '.line-length.line_length' "$mdconfig")" = "120" ]

echo "== markdownlint: a repo config suppresses the fallback"
touch .markdownlint.yml
: > "$GITHUB_OUTPUT"
run_step "Choose markdownlint config"
[ -z "$(sed -n 's/^path=//p' "$GITHUB_OUTPUT" | tail -1)" ]
rm .markdownlint.yml

echo "== prettier: npx fallback passes a clean fixture"
run_step prettier

echo "== prettier: npx fallback still flags unformatted files"
printf '{"a":1}\n' > ugly.json
expect_fail "unformatted json" prettier
rm ugly.json

echo "== secretlint: npx fallback loads the recommend preset cleanly"
run_step secretlint

echo "all fallback paths behave"
