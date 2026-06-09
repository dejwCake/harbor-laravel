#!/usr/bin/env bats
#
# Hermetic, snapshot-based tests for install.sh. They exercise only the tooling
# lay-down (install.sh ... --skip-create), so no Docker/composer is required: the
# curl shim (see tests/Dockerfile) serves a cached harbor-laravel tarball.

setup() {
  mkdir -p /workspace/tests/expected
}

mktemp_out() {
  echo "/workspace/tests/tmp.${1}.$(date +%s%N)"
}

snapshot_tree() {
  local dir="$1" out="$2"
  (cd "$dir" && find . -print | sort) > "$out"
}

snapshot_env_php_versions() {
  local env_file="$1" out="$2"
  if [ -f "$env_file" ]; then
    {
      grep -E '^HARBOR_PHP_VERSION=' "$env_file" || echo 'HARBOR_PHP_VERSION=<missing>'
      grep -E '^HARBOR_PHP_QA_VERSION=' "$env_file" || echo 'HARBOR_PHP_QA_VERSION=<missing>'
    } > "$out"
  else
    printf "<missing>\n" > "$out"
  fi
}

validate_or_init() {
  # Args: pairs of current:expected
  local init_needed=0
  for pair in "$@"; do
    local expected="${pair##*:}"
    [ -f "$expected" ] || init_needed=1
  done

  if [ "$init_needed" -eq 1 ]; then
    for pair in "$@"; do
      local current="${pair%%:*}" expected="${pair##*:}"
      [ -f "$expected" ] || cp "$current" "$expected"
    done
    skip "Initialized expected snapshots for scenario"
  else
    for pair in "$@"; do
      local current="${pair%%:*}" expected="${pair##*:}"
      run /usr/bin/env bash -lc "diff -u '$expected' '$current'"
      if [ "$status" -ne 0 ]; then
        echo "Snapshot mismatch: $(basename "$expected")" >&2
        echo "$output" >&2
        return 1
      fi
    done
  fi
}

harbor_info_snapshots() {
  local dir="$1" cur_ver_out="$2" cur_type_out="$3"
  if [ -x "$dir/harbor" ]; then
    (cd "$dir" && ./harbor -v) > "$cur_ver_out" 2>&1 || printf "<error>\n" > "$cur_ver_out"
    (cd "$dir" && ./harbor -t) > "$cur_type_out" 2>&1 || printf "<error>\n" > "$cur_type_out"
  else
    printf "<missing executable>\n" > "$cur_ver_out"
    printf "<missing executable>\n" > "$cur_type_out"
  fi
}

# run_scenario <name> <type> [extra install.sh args...]
run_scenario() {
  local name="$1" type="$2"; shift 2
  local dir="/workspace/test-real/${name}"
  rm -rf "$dir"

  run /usr/bin/env bash /workspace/install.sh "$type" "$dir" --skip-create "$@"
  [ "$status" -eq 0 ]

  # Harbor docs preserved; bootstrap-only artifacts stripped from the project.
  [ -f "$dir/harbor-README.md" ]
  [ -f "$dir/docker-compose.override.yml" ]
  [ ! -e "$dir/install.sh" ]
  [ ! -e "$dir/tests" ]

  local cur_tree cur_env_php cur_ver cur_type
  cur_tree=$(mktemp_out "${name}.tree")
  cur_env_php=$(mktemp_out "${name}.env.php")
  cur_ver=$(mktemp_out "${name}.version")
  cur_type=$(mktemp_out "${name}.type")

  snapshot_tree "$dir" "$cur_tree"
  snapshot_env_php_versions "$dir/.env.harbor" "$cur_env_php"
  harbor_info_snapshots "$dir" "$cur_ver" "$cur_type"

  validate_or_init \
    "$cur_tree:/workspace/tests/expected/${name}.tree.txt" \
    "$cur_env_php:/workspace/tests/expected/${name}.env.php.txt" \
    "$cur_ver:/workspace/tests/expected/${name}.version.txt" \
    "$cur_type:/workspace/tests/expected/${name}.type.txt"
}

# Laravel: default, --dev, then php 8.2..8.5
@test "laravel install snapshot (no php flag)" { run_scenario laravel-default laravel; }
@test "laravel install snapshot (--dev)"       { run_scenario laravel-dev     laravel --dev; }
@test "laravel install snapshot (php 8.2)"      { run_scenario laravel-82      laravel -p=8.2; }
@test "laravel install snapshot (php 8.3)"      { run_scenario laravel-83      laravel -p=8.3; }
@test "laravel install snapshot (php 8.4)"      { run_scenario laravel-84      laravel -p=8.4; }
@test "laravel install snapshot (php 8.5)"      { run_scenario laravel-85      laravel -p=8.5; }

# Craftable: default, --dev, then php 8.2..8.5
@test "craftable install snapshot (no php flag)" { run_scenario craftable-default craftable; }
@test "craftable install snapshot (--dev)"       { run_scenario craftable-dev     craftable --dev; }
@test "craftable install snapshot (php 8.2)"      { run_scenario craftable-82      craftable -p=8.2; }
@test "craftable install snapshot (php 8.3)"      { run_scenario craftable-83      craftable -p=8.3; }
@test "craftable install snapshot (php 8.4)"      { run_scenario craftable-84      craftable -p=8.4; }
@test "craftable install snapshot (php 8.5)"      { run_scenario craftable-85      craftable -p=8.5; }
