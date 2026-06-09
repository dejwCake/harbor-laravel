# syntax=docker/dockerfile:1
FROM alpine:3.20

# Install test dependencies: bash, git, curl, GNU tar (for --strip-components),
# gzip, and bats-core.
RUN apk add --no-cache bash git curl tar gzip

# Install bats-core
RUN git clone --depth 1 https://github.com/bats-core/bats-core.git /opt/bats-core \
 && /opt/bats-core/install.sh /usr/local

WORKDIR /workspace

# Copy repo into container
COPY . /workspace

# Install curl shim: serve local artifacts unless RUN_REAL=1.
# Unlike the old installer (which downloaded with `curl -o file` then unzipped),
# install.sh streams `curl -fsSL <url> | tar -xz`, so the shim must support both
# the `-o <out>` form and writing the archive to stdout. Archives are .tar.gz.
RUN printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
  'if [ "${RUN_REAL:-0}" -eq 1 ]; then exec /usr/bin/curl "$@"; fi' \
  'out=""' 'url=""' \
  'while [ "$#" -gt 0 ]; do' \
  '  case "$1" in' \
  '    -o|--output) shift; out="$1" ;;' \
  '    http*) url="$1" ;;' \
  '  esac' \
  '  shift || true' \
  'done' \
  'case "$url" in' \
  '  *github.com*/harbor-laravel/archive/*) tail="${url##*/}"; name="${tail%.tar.gz}"; src="/workspace/tests/artifacts/harbor-laravel-${name}.tar.gz" ;;' \
  '  *) echo "curl shim: unsupported URL $url (only harbor-laravel supported)" >&2; exit 2 ;;' \
  'esac' \
  '[ -f "$src" ] || { echo "curl shim: missing cached file: $src" >&2; exit 4; }' \
  'if [ -n "$out" ]; then cp "$src" "$out"; else cat "$src"; fi' \
  > /usr/local/bin/curl && chmod +x /usr/local/bin/curl

# Default command runs scenario tests only
CMD ["bats", "tests/scenarios.bats"]
