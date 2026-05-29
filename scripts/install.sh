#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="omarchy-environment-apply"
BIN_DIR="${HOME}/.local/bin"
SOURCE_URL=""
FORCE=false

usage() {
  cat <<'EOF'
install.sh

Install omarchy-environment-apply into a bin directory.

Usage:
  ./scripts/install.sh [--bin-dir DIR] [--force]
  ./scripts/install.sh --from URL [--bin-dir DIR] [--force]

Options:
  --bin-dir DIR  Install destination directory (default: ~/.local/bin)
  --from URL     Download the script from URL instead of the local checkout
  --force        Replace an existing installed script
  --help, -h     Show this help
EOF
}

die() {
  printf '[install:error] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

fetch_to_file() {
  local url="$1"
  local target="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$target"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$target" "$url"
  else
    die "Need curl or wget to download $SCRIPT_NAME"
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bin-dir)
        BIN_DIR="${2:-}"
        shift 2
        ;;
      --from)
        SOURCE_URL="${2:-}"
        shift 2
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done

  [[ -n "$BIN_DIR" ]] || die "--bin-dir cannot be empty"

  local script_dir source_path target_path temp_file
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source_path="$script_dir/../bin/$SCRIPT_NAME"
  target_path="$BIN_DIR/$SCRIPT_NAME"
  temp_file="$(mktemp)"
  trap 'rm -f "$temp_file"' EXIT

  if [[ -n "$SOURCE_URL" ]]; then
    fetch_to_file "$SOURCE_URL" "$temp_file"
  elif [[ -f "$source_path" ]]; then
    cp "$source_path" "$temp_file"
  else
    die "Local script not found next to install.sh. Use --from URL instead."
  fi

  mkdir -p "$BIN_DIR"

  if [[ -e "$target_path" && "$FORCE" != true ]]; then
    die "$target_path already exists. Re-run with --force to replace it."
  fi

  install -m 0755 "$temp_file" "$target_path"
  printf '[install] Installed %s to %s\n' "$SCRIPT_NAME" "$target_path"

  case ":$PATH:" in
    *":$BIN_DIR:"*)
      ;;
    *)
      printf '[install] Add %s to PATH if needed.\n' "$BIN_DIR"
      ;;
  esac
}

main "$@"