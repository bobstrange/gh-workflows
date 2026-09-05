#!/usr/bin/env bash
set -euo pipefail

# Gates common-shellcheck's file selection, a shell one-liner embedded in YAML
# that drifts silently. The run block is pulled out with yq at test time, so
# the code under test is the code that ships.

repo="$(git rev-parse --show-toplevel)"
hooks="$repo/lefthook/common.yml"
workflow="$repo/.github/workflows/lint.yml"

# The subset check reproduces file discovery from this revision of
# action-shellcheck. Moving the pin means re-reading its action.yaml.
action_sha=00cae500b08a931fb5698e11e79bfbd38e612a38
shebang_regex="^#! */[^ ]*/(env *)?[abk]*sh"

if ! command -v yq >/dev/null 2>&1; then
  echo "yq is required (preinstalled on GitHub runners)" >&2
  exit 1
fi

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pinned="$(grep -o 'ludeeus/action-shellcheck@[0-9a-f]\{40\}' "$workflow" | head -1 | cut -d@ -f2)"
[ "$pinned" = "$action_sha" ] ||
  fail "action-shellcheck pin moved to $pinned; re-read its file discovery and update action_sha"

fixture="$(mktemp -d)"
stub_bin="$(mktemp -d)"
trap 'rm -rf "$fixture" "$stub_bin"' EXIT

selected="$fixture/.selected"
cat > "$stub_bin/shellcheck" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$SELECTED"
STUB
chmod +x "$stub_bin/shellcheck"

write() { # <path> <first line>
  printf '%s\n' "$2" > "$fixture/$1"
}

write plain.sh '#!/bin/sh'
write tool.bash '#!/usr/bin/env bash'
write noext-exec-sh '#!/usr/bin/env sh'
write noext-exec-bash '#!/bin/bash'
write noext-exec-ksh '#!/bin/ksh'
write noext-noexec '#!/bin/sh'
write noext-exec-python '#!/usr/bin/env python3'
write noext-exec-fish '#!/usr/bin/env fish'
write noext-exec-zsh '#!/bin/zsh'
write noext-exec-plain 'just text, no shebang'
write config.zsh '#!/bin/zsh'
write script.sh.tmpl '#!/bin/sh'
write README.md '# not a script'

chmod +x "$fixture"/noext-exec-*

expected="noext-exec-bash
noext-exec-ksh
noext-exec-sh
plain.sh
tool.bash"

cd "$fixture"

template="$(yq '.pre-commit.commands.common-shellcheck.run' "$hooks")"
mapfile -t files < <(find . -maxdepth 1 -type f ! -name '.selected' -printf '%P\n' | sort)
: > "$selected"
SELECTED="$selected" PATH="$stub_bin:$PATH" \
  bash -c "${template/\{staged_files\}/$(printf '%q ' "${files[@]}")}"

got="$(sort "$selected")"
[ "$got" = "$expected" ] || {
  echo "--- selected ---"; echo "$got"
  echo "--- expected ---"; echo "$expected"
  fail "hook selected the wrong files"
}
echo "== selection: matches the expected set"

# Only the action's shebang clause is reproduced: every name pattern the hook
# uses is already one of the action's, so that half cannot go out of subset.
{
  find . -maxdepth 1 -type f '(' -name '*.bash' -o -name '.bashrc' -o -name 'bashrc' \
    -o -name '*.ksh' -o -name '*.zsh' -o -name '.zshrc' -o -name 'zshrc' \
    -o -name '*.sh' -o -name '*.shlib' ')' -printf '%P\n'
  find . -maxdepth 1 -type f ! -name '*.*' -perm /111 -printf '%P\n' |
    while read -r f; do
      head -n1 "$f" | grep -Eqs "$shebang_regex" || continue
      printf '%s\n' "$f"
    done
} | sort -u > "$fixture/.ci"

if extra="$(comm -23 <(echo "$got") "$fixture/.ci")" && [ -n "$extra" ]; then
  echo "$extra"
  fail "hook selects files CI does not scan -- stricter than CI"
fi
echo "== subset: every selected file is one CI scans too"

while read -r verdict line; do
  if echo "$line" | grep -Eqs "$shebang_regex"; then got=select; else got=skip; fi
  [ "$got" = "$verdict" ] || fail "shebang '$line' expected $verdict, got $got"
done <<'CASES'
select #!/bin/sh
select #! /bin/sh
select #!/usr/bin/env sh
select #!/bin/bash
select #!/usr/bin/env bash
select #!/bin/ksh
skip #!/bin/dash
skip #!/bin/zsh
skip #!/usr/bin/env zsh
skip #!/usr/bin/env fish
skip #!/usr/bin/env python3
skip #!/usr/bin/env ruby
skip #!/usr/bin/perl
CASES
echo "== shebang: classifies each interpreter as expected"

echo "OK"
