#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/bin/omarchy-environment-apply"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TEST_HOME="$TMP_DIR/home"
STUB_DIR="$TMP_DIR/stubs"
LOG_FILE="$TMP_DIR/calls.log"

mkdir -p "$TEST_HOME" "$STUB_DIR"
mkdir -p "$TMP_DIR/pacman-sync"

create_stub() {
  local name="$1"
  cat >"$STUB_DIR/$name" <<EOF
#!/bin/sh
echo "$name \$*" >>"$LOG_FILE"
  if [ "$name" = "curl" ]; then
  out=""
  url=""
  while [ \$# -gt 0 ]; do
    if [ "\$1" = "-o" ]; then
      out="\$2"
      shift 2
      continue
    fi
    case "\$1" in
      http://*|https://*)
        url="\$1"
        ;;
    esac
    shift
  done
  if [ -n "\$out" ]; then
    case "\$url" in
      *environment.json)
        cp "$TMP_DIR/config.json" "\$out"
        ;;
      *)
        echo "fake" >"\$out"
        ;;
    esac
  fi
  fi
if [ "$name" = "pacman-conf" ]; then
  if [ "\$1" = "--repo-list" ]; then
    printf '%s\n' core extra omarchy
  fi
fi
exit 0
EOF
  chmod +x "$STUB_DIR/$name"
}

for cmd in \
  omarchy-theme-install \
  omarchy-theme-set \
  omarchy-theme-bg-set \
  omarchy-restart-waybar \
  omarchy-restart-walker \
  omarchy-install-browser \
  omarchy-remove-browser \
  omarchy-install-vscode \
  omarchy-webapp-install \
  omarchy-webapp-remove \
  omarchy \
  omarchy-pkg-add \
  omarchy-pkg-drop \
  hyprctl \
  pacman-conf \
  sudo \
  pacman \
  git \
  curl; do
  create_stub "$cmd"
done

mkdir -p "$TEST_HOME/.config/waybar"
mkdir -p "$TMP_DIR/assets"
echo "local wallpaper" >"$TMP_DIR/assets/ocean.jpg"
echo "font-size: 12px;" >"$TEST_HOME/.config/waybar/style.css"

cat >"$TMP_DIR/config.json" <<EOF
{
  "version": 1,
  "themes": {
    "install": [
      {"repo": "https://github.com/example/omarchy-ocean-theme.git", "apply_theme": true}
    ],
    "backgrounds": [
      {"theme": "ocean", "source": "ocean.jpg", "target_name": "ocean.jpg", "set_as_default": true}
    ]
  },
  "files": [
    {"path": "~/.bashrc", "action": "ensure_line", "content": "source /usr/share/nvm/init-nvm.sh"},
    {"path": "~/.config/waybar/style.css", "action": "replace", "search": "12px", "replace": "13px"},
    {"path": "~/.config/waybar/style.css", "action": "ensure_line", "content": "#clock { color: #ffffff; }"}
  ],
  "browsers": {"add": ["google-chrome"], "remove": ["firefox"]},
  "editors": {"add": ["code"], "remove": []},
  "packages": {
    "add": ["ripgrep", "nvm"],
    "remove": ["thunderbird"]
  },
  "web_apps": {
    "add": [{"name": "Linear", "url": "https://linear.app", "browser": "google-chrome-stable"}],
    "remove": ["Legacy Tool"]
  }
}
EOF

PATH="$STUB_DIR:$PATH" HOME="$TEST_HOME" PACMAN_SYNC_DIR="$TMP_DIR/pacman-sync" "$SCRIPT" "$TMP_DIR/config.json"
PATH="$STUB_DIR:$PATH" HOME="$TEST_HOME" PACMAN_SYNC_DIR="$TMP_DIR/pacman-sync" "$SCRIPT" github:example/omarchy-ocean-theme

cat >"$TMP_DIR/minimal.json" <<EOF
{"version":1}
EOF
minimal_output="$(PATH="$STUB_DIR:$PATH" HOME="$TEST_HOME" PACMAN_SYNC_DIR="$TMP_DIR/pacman-sync" "$SCRIPT" "$TMP_DIR/minimal.json" 2>&1)"
if printf '%s' "$minimal_output" | grep -Fq "jq:"; then
  echo "Assertion failed: minimal config emitted jq error"
  echo "$minimal_output"
  exit 1
fi

echo "url=https://old.example/a" >"$TMP_DIR/replace.txt"
cat >"$TMP_DIR/replace.json" <<EOF
{
  "version": 1,
  "files": [
    {
      "path": "$TMP_DIR/replace.txt",
      "action": "replace",
      "search": "https://old.example/a",
      "replace": "https://new.example/b?x=1&y=2"
    }
  ]
}
EOF
PATH="$STUB_DIR:$PATH" HOME="$TEST_HOME" PACMAN_SYNC_DIR="$TMP_DIR/pacman-sync" "$SCRIPT" "$TMP_DIR/replace.json"

assert_contains() {
  local needle="$1"
  local haystack="$2"
  if ! grep -Fq "$needle" "$haystack"; then
    echo "Assertion failed: expected to find '$needle' in $haystack"
    echo "----"
    cat "$haystack"
    exit 1
  fi
}

assert_file_exists() {
  local f="$1"
  [[ -f "$f" ]] || { echo "Assertion failed: missing file $f"; exit 1; }
}

assert_contains "omarchy-theme-install https://github.com/example/omarchy-ocean-theme.git" "$LOG_FILE"
assert_contains "curl -fsSL https://raw.githubusercontent.com/example/omarchy-ocean-theme/HEAD/environment.json" "$LOG_FILE"
assert_contains "curl -fsSL https://raw.githubusercontent.com/example/omarchy-ocean-theme/HEAD/assets/ocean.jpg" "$LOG_FILE"
assert_contains "omarchy-theme-bg-set $TEST_HOME/.config/omarchy/backgrounds/ocean/ocean.jpg" "$LOG_FILE"
assert_contains "omarchy-restart-waybar" "$LOG_FILE"
assert_contains "sudo pacman -Sy --noconfirm" "$LOG_FILE"
assert_contains "omarchy-install-browser chrome" "$LOG_FILE"
assert_contains "omarchy-install-vscode" "$LOG_FILE"
assert_contains "omarchy-pkg-add ripgrep nvm" "$LOG_FILE"
assert_contains "omarchy-remove-browser firefox" "$LOG_FILE"
assert_contains "omarchy-pkg-drop thunderbird" "$LOG_FILE"
assert_contains "omarchy-webapp-install Linear https://linear.app" "$LOG_FILE"
assert_contains "omarchy-webapp-remove Legacy Tool" "$LOG_FILE"
assert_contains "omarchy-restart-walker" "$LOG_FILE"

assert_contains "13px" "$TEST_HOME/.config/waybar/style.css"
assert_contains "#clock { color: #ffffff; }" "$TEST_HOME/.config/waybar/style.css"
assert_contains "https://new.example/b?x=1&y=2" "$TMP_DIR/replace.txt"

assert_file_exists "$TEST_HOME/.config/omarchy/backgrounds/ocean/ocean.jpg"

assert_contains "source /usr/share/nvm/init-nvm.sh" "$TEST_HOME/.bashrc"

echo "All tests passed."
