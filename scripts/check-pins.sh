#!/usr/bin/env bash
set -euo pipefail

# The inline fallback pins (lint.yml env: block, lefthook/common.yml) are
# maintained by hand while package.json is Dependabot-managed — see CLAUDE.md
# "Version pins". This fails CI as soon as they drift apart.

cd "$(git rev-parse --show-toplevel)"

fail=0

want() {
  node -p "require('./package.json').devDependencies['$1']"
}

check() { # <file> <label> <actual> <expected>
  if [ -z "$3" ]; then
    echo "$1: no pin found for $2 (extraction pattern broken?)" >&2
    fail=1
  elif [ "$3" != "$4" ]; then
    echo "$1: $2 pinned at $3, the Dependabot-managed pin is $4" >&2
    fail=1
  fi
}

lint_env() { # <VAR> — value of an env: pin in lint.yml
  sed -n "s/^ *$1: \"\(.*\)\"$/\1/p" .github/workflows/lint.yml
}

check .github/workflows/lint.yml PRETTIER_VERSION \
  "$(lint_env PRETTIER_VERSION)" "$(want prettier)"
check .github/workflows/lint.yml SECRETLINT_VERSION \
  "$(lint_env SECRETLINT_VERSION)" "$(want secretlint)"

# yamllint is Python: Dependabot watches requirements.txt, the workflow
# mirrors it in env: (it cannot read this repo's files at run time).
check .github/workflows/lint.yml YAMLLINT_VERSION \
  "$(lint_env YAMLLINT_VERSION)" \
  "$(sed -n 's/^yamllint==\(.*\)$/\1/p' requirements.txt)"

# Every inline <package>@<version> occurrence in the hooks config. The
# secretlint pattern cannot match inside the preset name: there "@<digit>"
# only ever follows "-recommend".
for pkg in prettier secretlint markdownlint-cli2 \
  @secretlint/secretlint-rule-preset-recommend; do
  versions="$(grep -oE "$pkg@[0-9][0-9A-Za-z.-]*" lefthook/common.yml |
    sed "s|^$pkg@||" | sort -u)"
  if [ -z "$versions" ]; then
    check lefthook/common.yml "$pkg" "" ""
  else
    while read -r version; do
      check lefthook/common.yml "$pkg" "$version" "$(want "$pkg")"
    done <<<"$versions"
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "all inline pins match their Dependabot-managed sources"
fi
exit "$fail"
