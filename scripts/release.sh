#!/usr/bin/env bash
set -euo pipefail

# Tags the next semver release and moves the matching major tag (e.g. v1) to
# it, so consumers on the moving tag pick the release up.
# Usage: scripts/release.sh [patch|minor|major]   (default: patch)

bump="${1:-patch}"
case "$bump" in
  patch | minor | major) ;;
  *)
    echo "usage: $0 [patch|minor|major]" >&2
    exit 1
    ;;
esac

branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$branch" != "main" ]; then
  echo "release must be cut from main (current: $branch)" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "working tree is not clean" >&2
  exit 1
fi

# --force: the moving major tag legitimately changes; without it a second
# clone refuses the fetch once v1 has moved anywhere else.
git fetch origin --tags --force
if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
  echo "main is not in sync with origin/main" >&2
  exit 1
fi

# A release fans out to every consumer at once, so refuse to tag a commit
# whose CI is not green.
if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required to verify CI status" >&2
  exit 1
fi
sha="$(git rev-parse HEAD)"
conclusion="$(gh run list --commit "$sha" --workflow CI \
  --json conclusion --jq '.[0].conclusion // "missing"')"
if [ "$conclusion" != "success" ]; then
  echo "CI for $sha is not green (status: $conclusion); refusing to release" >&2
  exit 1
fi

latest="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1)"
if [ -z "$latest" ]; then
  next="v1.0.0"
else
  IFS=. read -r major minor patch <<<"${latest#v}"
  case "$bump" in
    patch) next="v${major}.${minor}.$((patch + 1))" ;;
    minor) next="v${major}.$((minor + 1)).0" ;;
    major) next="v$((major + 1)).0.0" ;;
  esac
fi

major_tag="${next%%.*}"
git tag "$next"
git tag -f "$major_tag" "$next"
# --atomic: never leave v1.x.y published with the major tag still behind.
git push --atomic origin "refs/tags/$next" "+refs/tags/$major_tag"
echo "released $next ($major_tag now points at it)"
