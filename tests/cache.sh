#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Download and cache the harbor-laravel tarball into tests/artifacts.
# Usage: bash tests/cache.sh [branch_or_tag]
# Default branch/tag: main

BRANCH_OR_TAG="${1:-main}"
BASE_URL="https://github.com/dejwCake"
ART_DIR="tests/artifacts"
mkdir -p "$ART_DIR"

fetch() {
  local repo="$1" out="$2"
  echo "Caching $repo @ $BRANCH_OR_TAG -> $out"
  curl --fail --location "$BASE_URL/$repo/archive/$BRANCH_OR_TAG.tar.gz" -o "$out"
}

fetch harbor-laravel "$ART_DIR/harbor-laravel-$BRANCH_OR_TAG.tar.gz"

echo "Cached artifacts in $ART_DIR:"
ls -la "$ART_DIR"
