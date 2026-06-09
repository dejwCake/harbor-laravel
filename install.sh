#!/usr/bin/env bash

# Harbor bootstrap installer.
#
# Scaffolds a new Harbor-based Laravel or Craftable project: downloads the
# harbor-laravel tooling from GitHub, lays it into the target directory,
# optionally pins the PHP version, then hands off to the project-local
# `./harbor create-project`.
#
# Usage:
#   install.sh <laravel|craftable> <path> [options]
#   curl -fsSL https://raw.githubusercontent.com/dejwCake/harbor-laravel/main/install.sh \
#     | bash -s -- <laravel|craftable> <path> [options]
#
# All logic lives in main(), invoked on the final line, so a truncated download
# can never execute partial code.

set -euo pipefail
IFS=$'\n\t'

REPO_URL="https://github.com/dejwCake/harbor-laravel"

usage() {
    cat <<'USAGE'
Usage:
  install.sh <laravel|craftable> <path> [options]
  curl -fsSL .../install.sh | bash -s -- <laravel|craftable> <path> [options]

Options:
  -b=<branch>, --branch=<branch>   Harbor branch to fetch (default: main)
  -t=<tag>,    --tag=<tag>         Harbor tag to fetch (alias of --branch/--ref)
  --ref=<ref>                      Branch, tag, or commit SHA (default: main)
  -p=<ver>,    --php=<ver>         PHP version: 8.2|8.3|8.4|8.5
  --dev                            Composer minimum-stability dev (laravel + craftable)
  --starter[=react|svelte|vue|livewire]
                                   Use a starter kit (bare = interactive, needs TTY)
  --skip-create                    Lay down Harbor tooling only; skip create-project
  -h, --help                       Show this help
USAGE
}

requireDeps() {
    # curl + tar are always needed to fetch/lay down the tooling; docker is only
    # needed for the create-project hand-off (skipped with --skip-create).
    local deps=(curl tar)
    [[ "$SKIP_CREATE" -eq 1 ]] || deps+=(docker)

    local missing=()
    for dep in "${deps[@]}"; do
        command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing required tools: ${missing[*]}" >&2
        echo "Please install them and retry." >&2
        exit 1
    fi
}

# Idempotent .env.harbor key setter (copied from harbor-installer).
# Usage: set_env_kv <file> <KEY> <VALUE>
set_env_kv() {
    local file="$1" key="$2" val="$3"
    if [[ -f "$file" ]]; then
        awk -v k="$key" -v v="$val" '
            BEGIN{found=0}
            $0 ~ "^"k"=" {print k"="v; found=1; next}
            {print}
            END{ if(found==0) print k"="v }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    else
        printf "%s=%s\n" "$key" "$val" > "$file"
    fi
}

parseArgs() {
    TYPE=""; DIR=""; REF="main"; PHP=""; STARTER=""; DEV=0; SKIP_CREATE=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b=*|--branch=*|-t=*|--tag=*|--ref=*) REF="${1#*=}" ;;
            -p=*|--php=*)                         PHP="${1#*=}" ;;
            --dev)                                DEV=1 ;;
            --starter)                            STARTER="interactive" ;;
            --starter=*)                          STARTER="${1#*=}" ;;
            --skip-create)                        SKIP_CREATE=1 ;;
            -h|--help)                            usage; exit 0 ;;
            -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
            *)
                if [[ -z "$TYPE" ]]; then
                    TYPE="$1"
                elif [[ -z "$DIR" ]]; then
                    DIR="$1"
                else
                    echo "Unexpected argument: $1" >&2; exit 1
                fi
                ;;
        esac
        shift
    done
}

validate() {
    case "$TYPE" in
        laravel|craftable) ;;
        *) echo "Type must be laravel|craftable." >&2; usage >&2; exit 1 ;;
    esac

    [[ -n "$DIR" ]] || { echo "No target path provided." >&2; usage >&2; exit 1; }

    [[ -z "$PHP" || "$PHP" =~ ^8\.[2-5]$ ]] \
        || { echo "Unsupported PHP version: $PHP (allowed: 8.2, 8.3, 8.4, 8.5)" >&2; exit 1; }

    case "$STARTER" in
        ""|interactive|react|svelte|vue|livewire) ;;
        *) echo "Unsupported starter kit: $STARTER (allowed: react, svelte, vue, livewire)" >&2; exit 1 ;;
    esac

    if [[ "$STARTER" == "interactive" && ! -t 0 ]]; then
        echo "Bare --starter needs a terminal; when piping, pass --starter=react|svelte|vue|livewire." >&2
        exit 1
    fi

    [[ ! -e "$DIR" || ( -d "$DIR" && -z "$(ls -A "$DIR" 2>/dev/null)" ) ]] \
        || { echo "Target '$DIR' exists and is not empty." >&2; exit 1; }
}

main() {
    parseArgs "$@"
    validate
    requireDeps

    mkdir -p "$DIR"
    cd "$DIR"

    echo "Downloading Harbor tooling @ ${REF} ..."
    if ! curl -fsSL "${REPO_URL}/archive/${REF}.tar.gz" | tar -xz --strip-components=1; then
        echo "Download/extract failed for ${REPO_URL}/archive/${REF}.tar.gz" >&2
        exit 1
    fi

    # Drop bootstrap-only artifacts so the new project doesn't carry them.
    rm -f  install.sh
    rm -rf tests
    rm -f  .gitignore
    [[ -f README.md ]] && mv README.md harbor-README.md
    chmod +x ./harbor 2>/dev/null || true

    if [[ -n "$PHP" ]]; then
        echo "Pinning PHP version to ${PHP} in .env.harbor ..."
        set_env_kv ".env.harbor" "HARBOR_PHP_VERSION"    "$PHP"
        set_env_kv ".env.harbor" "HARBOR_PHP_QA_VERSION" "$PHP"
    fi

    if [[ -f docker-compose.override.example.yml ]]; then
        cp docker-compose.override.example.yml docker-compose.override.yml
    fi

    if [[ "$SKIP_CREATE" -eq 1 ]]; then
        echo "Harbor tooling laid down in '${DIR}' (--skip-create; skipping create-project)."
        return 0
    fi

    # Forward flags to the project-local harbor.
    local -a flags=()
    case "$STARTER" in
        interactive) flags+=(--starter) ;;
        "")          ;;
        *)           flags+=(--starter="$STARTER") ;;
    esac
    [[ "$DEV" -eq 1 ]] && flags+=(--dev)

    echo "Scaffolding ${TYPE} project ..."
    ./harbor create-project "$TYPE" "${flags[@]}"
}

main "$@"
