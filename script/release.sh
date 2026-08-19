#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/Config/Version.xcconfig"
REMOTE_NAME="origin"
RELEASE_VERSION=""
ASSUME_YES=false
DRY_RUN=false

usage() {
  cat <<'EOF'
usage: ./script/release.sh [--version <x.y.z>] [--yes] [--dry-run]

Prepare and publish a CueDex release. With no arguments, the script suggests
the next patch version and asks for confirmation.

  --version <x.y.z>  Set the release version without prompting for it
  --yes              Skip the final confirmation
  --dry-run          Validate and print the plan without changing anything
  -h, --help         Show this help

Publishing updates Config/Version.xcconfig, creates a release commit and an
annotated v<x.y.z> tag, then pushes both to origin. GitHub Actions builds the
x86_64 and arm64 DMGs and attaches them to the GitHub Release.
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

read_setting() {
  local key="$1"
  awk -F ' = ' -v key="$key" '$1 == key { print $2 }' "$VERSION_FILE"
}

replace_setting() {
  local key="$1"
  local value="$2"
  sed -i '' -E "s/^${key} = .*$/${key} = ${value}/" "$VERSION_FILE"
}

next_patch_version() {
  local version="$1"
  local major minor patch
  IFS=. read -r major minor patch <<< "$version"
  printf '%s.%s.%s\n' "$major" "$minor" "$((patch + 1))"
}

version_is_greater() {
  local candidate="$1"
  local current="$2"
  local index
  local -a candidate_parts current_parts
  IFS=. read -r -a candidate_parts <<< "$candidate"
  IFS=. read -r -a current_parts <<< "$current"

  for index in 0 1 2; do
    if ((10#${candidate_parts[$index]} > 10#${current_parts[$index]})); then
      return 0
    fi
    if ((10#${candidate_parts[$index]} < 10#${current_parts[$index]})); then
      return 1
    fi
  done
  return 1
}

github_repository_url() {
  local remote_url="$1"
  case "$remote_url" in
    git@github.com:*.git)
      printf 'https://github.com/%s\n' "${remote_url#git@github.com:}" | sed 's/\.git$//'
      ;;
    https://github.com/*.git)
      printf '%s\n' "${remote_url%.git}"
      ;;
    https://github.com/*)
      printf '%s\n' "$remote_url"
      ;;
    *)
      return 1
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || fail "--version requires a value"
      RELEASE_VERSION="$2"
      shift 2
      ;;
    --yes)
      ASSUME_YES=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

cd "$ROOT_DIR"

[[ -f "$VERSION_FILE" ]] || fail "missing $VERSION_FILE"
[[ "$(git rev-parse --show-toplevel)" == "$ROOT_DIR" ]] || fail "run this script from the CueDex repository"
[[ "$(git branch --show-current)" == "main" ]] || fail "releases must be created from main"
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || fail "tracked files must be clean before releasing"
git remote get-url "$REMOTE_NAME" >/dev/null 2>&1 || fail "missing $REMOTE_NAME remote"

CURRENT_VERSION="$(read_setting MARKETING_VERSION)"
CURRENT_BUILD="$(read_setting CURRENT_PROJECT_VERSION)"
VERSION_PATTERN='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
[[ "$CURRENT_VERSION" =~ $VERSION_PATTERN ]] || fail "invalid current version: $CURRENT_VERSION"
[[ "$CURRENT_BUILD" =~ ^[0-9]+$ ]] || fail "invalid current build number: $CURRENT_BUILD"

SUGGESTED_VERSION="$(next_patch_version "$CURRENT_VERSION")"
if [[ -z "$RELEASE_VERSION" ]]; then
  if [[ ! -t 0 ]]; then
    fail "--version is required when standard input is not interactive"
  fi
  read -r -p "Release version [$SUGGESTED_VERSION]: " RELEASE_VERSION
  RELEASE_VERSION="${RELEASE_VERSION:-$SUGGESTED_VERSION}"
fi

[[ "$RELEASE_VERSION" =~ $VERSION_PATTERN ]] || fail "version must use x.y.z format without leading zeroes"
version_is_greater "$RELEASE_VERSION" "$CURRENT_VERSION" || fail "version must be greater than $CURRENT_VERSION"

NEXT_BUILD="$((CURRENT_BUILD + 1))"
TAG_NAME="v$RELEASE_VERSION"

git rev-parse --verify --quiet "refs/tags/$TAG_NAME" >/dev/null && fail "local tag already exists: $TAG_NAME"
git ls-remote --exit-code --tags "$REMOTE_NAME" "refs/tags/$TAG_NAME" >/dev/null 2>&1 && fail "remote tag already exists: $TAG_NAME"

echo
echo "CueDex release plan"
echo "  Version: $CURRENT_VERSION -> $RELEASE_VERSION"
echo "  Build:   $CURRENT_BUILD -> $NEXT_BUILD"
echo "  Tag:     $TAG_NAME"
echo "  Output:  x86_64 and arm64 unsigned DMGs"

if $DRY_RUN; then
  echo
  echo "Dry run complete. No files, commits, tags, or remotes were changed."
  exit 0
fi

if ! $ASSUME_YES; then
  [[ -t 0 ]] || fail "--yes is required when standard input is not interactive"
  read -r -p "Continue? [y/N] " confirmation
  [[ "$confirmation" =~ ^[Yy]$ ]] || {
    echo "Release cancelled."
    exit 0
  }
fi

echo "Checking remote main..."
git fetch "$REMOTE_NAME" main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse "$REMOTE_NAME/main")" ]] || fail "local main must match $REMOTE_NAME/main"

replace_setting MARKETING_VERSION "$RELEASE_VERSION"
replace_setting CURRENT_PROJECT_VERSION "$NEXT_BUILD"

git add "$VERSION_FILE"
git diff --cached --check
git commit -m "chore: release $TAG_NAME"
git tag -a "$TAG_NAME" -m "CueDex $RELEASE_VERSION"
git push --atomic "$REMOTE_NAME" main "refs/tags/$TAG_NAME"

REMOTE_URL="$(git remote get-url "$REMOTE_NAME")"
if REPOSITORY_URL="$(github_repository_url "$REMOTE_URL")"; then
  echo
  echo "Release started: $REPOSITORY_URL/actions"
  echo "Release page:    $REPOSITORY_URL/releases/tag/$TAG_NAME"
else
  echo
  echo "Release started. Follow the $TAG_NAME workflow on the repository host."
fi
