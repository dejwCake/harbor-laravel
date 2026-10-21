#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Usage:
#   bash tests/run.sh                           # run all scenarios
#   bash tests/run.sh --local                   # test the working tree (uncommitted changes)
#   bash tests/run.sh --cache v6                # test a pushed branch/tag
#   bash tests/run.sh --filter 'laravel.*8\.2' # run only matching tests
#   bash tests/run.sh --regenerate-snapshots    # overwrite expected snapshots with current output
#   bash tests/run.sh --list                   # list test names
#   bash tests/run.sh --help                    # show usage

FILTER=""
LIST=0
SHOW_HELP=0
REAL=0
LOCAL=0
REGENERATE=0
REF="main"
ART_DIR="tests/artifacts"
REFRESH_CACHE=0

# Parse options
while [ $# -gt 0 ]; do
  case "${1}" in
    --filter)
      FILTER="${2:-}"
      shift 2 || true
      ;;
    --list)
      LIST=1
      shift 1
      ;;
    --help|-h)
      SHOW_HELP=1
      shift 1
      ;;
    --real)
      REAL=1
      shift 1
      ;;
    --cache)
      REF="${2:-main}"
      REFRESH_CACHE=1
      shift 2 || true
      ;;
    --local)
      LOCAL=1
      shift 1
      ;;
    --regenerate-snapshots)
      REGENERATE=1
      shift 1
      ;;
    *)
      echo "Unknown option: $1" >&2
      SHOW_HELP=1
      shift 1
      ;;
  esac
done

if [ "$SHOW_HELP" -eq 1 ]; then
  cat <<'USAGE'
Usage:
  bash tests/run.sh                           # run all scenarios against cached main
  bash tests/run.sh --local                   # run against the working tree (incl. uncommitted changes)
  bash tests/run.sh --cache <branch|tag>      # refresh the cache for <ref> and run against it
  bash tests/run.sh --real                    # use real GitHub downloads
  bash tests/run.sh --filter '<regex>'        # run only matching tests
  bash tests/run.sh --regenerate-snapshots    # overwrite expected snapshots (combine with the above)
  bash tests/run.sh --list                   # list test names
USAGE
  exit 0
fi

# Fast path: list locally without Docker
if [ "$LIST" -eq 1 ]; then
  sed -nE 's/^@test[[:space:]]+"([^"]+)".*/\1/p' tests/scenarios.bats
  exit 0
fi

if [ "$LOCAL" -eq 1 ] && { [ "$REAL" -eq 1 ] || [ "$REFRESH_CACHE" -eq 1 ]; }; then
  echo "--local cannot be combined with --real or --cache" >&2
  exit 1
fi

# Build test image
docker build -f tests/Dockerfile -t harbor-laravel-tests .

# Ensure expected snapshots directory exists on host
mkdir -p tests/expected
# Ensure artifacts directory exists and optionally refresh cache
mkdir -p "$ART_DIR"
if [ "$LOCAL" -eq 1 ]; then
  # Pack the working tree (tracked + untracked, minus ignored) like a GitHub archive
  # of a pseudo-ref "local"; the curl shim serves it for .../archive/local.tar.gz.
  REF="local"
  PACK_DIR=$(mktemp -d)
  mkdir "$PACK_DIR/harbor-laravel-local"
  # Skip files deleted from the working tree but still in the index
  git ls-files -z --cached --others --exclude-standard \
    | while IFS= read -r -d '' f; do if [ -e "$f" ]; then printf '%s\0' "$f"; fi; done \
    | COPYFILE_DISABLE=1 tar --null -T - -cf - \
    | tar -xf - -C "$PACK_DIR/harbor-laravel-local"
  COPYFILE_DISABLE=1 tar -czf "$ART_DIR/harbor-laravel-local.tar.gz" -C "$PACK_DIR" harbor-laravel-local
  rm -rf "$PACK_DIR"
  echo "Packed working tree -> $ART_DIR/harbor-laravel-local.tar.gz"
else
  CACHE_FILE="$ART_DIR/harbor-laravel-$REF.tar.gz"
  if [ "$REFRESH_CACHE" -eq 1 ] || [ ! -f "$CACHE_FILE" ]; then
    bash tests/cache.sh "$REF"
  fi
fi

# Base docker run args
RUN_ARGS=(--rm -v "$(pwd)/tests/expected:/workspace/tests/expected" -v "$(pwd)/$ART_DIR:/workspace/tests/artifacts" -e "HARBOR_REF=$REF" -e "UPDATE_SNAPSHOTS=$REGENERATE")
if [ "$REAL" -eq 1 ]; then
  RUN_ARGS+=( -e RUN_REAL=1 )
else
  RUN_ARGS+=( -e RUN_REAL=0 )
fi

if [ -n "$FILTER" ]; then
  # Run only filtered scenarios
  exec docker run "${RUN_ARGS[@]}" harbor-laravel-tests bats -f "$FILTER" tests/scenarios.bats
fi

# Run all scenarios by default
exec docker run "${RUN_ARGS[@]}" harbor-laravel-tests