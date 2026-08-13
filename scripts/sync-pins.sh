#!/usr/bin/env bash
set -euo pipefail

# Inverse of check-pins.sh: rewrites the hand-maintained inline fallback pins
# (lint.yml env: block, lefthook/common.yml) from their Dependabot-managed
# sources (package.json, requirements.txt), then re-runs the check. Turns a
# Dependabot bump from three hand edits into one command — see CLAUDE.md
# "Version pins".

cd "$(git rev-parse --show-toplevel)"

want() {
  node -p "require('./package.json').devDependencies['$1']"
}

require_version() { # <label> <value> — refuse anything that is not a version
  if ! printf '%s' "$2" | grep -qE '^[0-9][0-9A-Za-z.-]*$'; then
    echo "unusable $1 version: '$2'" >&2
    exit 1
  fi
}

sed_i() { # <script> <file> — in-place sed portable across BSD/GNU
  local tmp
  tmp="$(mktemp)"
  sed "$1" "$2" >"$tmp"
  mv "$tmp" "$2"
}

prettier="$(want prettier)"
secretlint="$(want secretlint)"
preset="$(want @secretlint/secretlint-rule-preset-recommend)"
markdownlint="$(want markdownlint-cli2)"
yamllint="$(sed -n 's/^yamllint==\(.*\)$/\1/p' requirements.txt)"

require_version prettier "$prettier"
require_version secretlint "$secretlint"
require_version secretlint-rule-preset-recommend "$preset"
require_version markdownlint-cli2 "$markdownlint"
require_version yamllint "$yamllint"

sed_i "s|^\( *PRETTIER_VERSION: \)\".*\"\$|\1\"$prettier\"|" \
  .github/workflows/lint.yml
sed_i "s|^\( *SECRETLINT_VERSION: \)\".*\"\$|\1\"$secretlint\"|" \
  .github/workflows/lint.yml
sed_i "s|^\( *YAMLLINT_VERSION: \)\".*\"\$|\1\"$yamllint\"|" \
  .github/workflows/lint.yml

# The bare-secretlint pattern cannot match inside the preset name: there
# "@<digit>" only ever follows "-recommend" (same reasoning as check-pins.sh).
sed_i "
  s|prettier@[0-9][0-9A-Za-z.-]*|prettier@$prettier|g
  s|markdownlint-cli2@[0-9][0-9A-Za-z.-]*|markdownlint-cli2@$markdownlint|g
  s|secretlint-rule-preset-recommend@[0-9][0-9A-Za-z.-]*|secretlint-rule-preset-recommend@$preset|g
  s|secretlint@[0-9][0-9A-Za-z.-]*|secretlint@$secretlint|g
" lefthook/common.yml

scripts/check-pins.sh
