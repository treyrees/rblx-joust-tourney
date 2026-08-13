#!/usr/bin/env bash
# install-toolchain.sh — install every binary the gates need, at the versions pinned in
# tools/toolchain.env. Idempotent: an already-present binary at the right version is left alone.
#
# Used by BOTH .github/workflows/gates.yml and .claude/hooks/session-start.sh, so CI and a session
# run the identical toolchain. Everything is a prebuilt release download (seconds), never a
# from-source build (minutes).
#
# Usage:
#   tools/install-toolchain.sh            # install everything
#   tools/install-toolchain.sh lune       # install just one component (lune | luau-lsp | rojo | defs)
#
# Installs into $JOUST_TOOLS (default ~/.joust-tools/bin). Print the directory to add to PATH with:
#   tools/install-toolchain.sh --print-path
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/toolchain.env
source "$REPO_ROOT/tools/toolchain.env"

TOOLS_DIR="${JOUST_TOOLS:-$HOME/.joust-tools}"
BIN_DIR="$TOOLS_DIR/bin"
SHARE_DIR="$TOOLS_DIR/share"

if [ "${1:-}" = "--print-path" ]; then
  echo "$BIN_DIR"
  exit 0
fi

mkdir -p "$BIN_DIR" "$SHARE_DIR"

log() { echo "[toolchain] $*" >&2; }

# Extract a single binary out of a release zip into BIN_DIR.
fetch_zip_binary() {
  local name="$1" url="$2" binary_in_zip="$3"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/pkg.zip" "$url"
  unzip -q "$tmp/pkg.zip" -d "$tmp/pkg"
  # The archives are flat today, but find keeps this working if upstream ever adds a top-level dir.
  local found
  found="$(find "$tmp/pkg" -type f -name "$binary_in_zip" | head -1)"
  if [ -z "$found" ]; then
    log "ERROR: '$binary_in_zip' not found inside $url"
    rm -rf "$tmp"
    exit 1
  fi
  install -m 0755 "$found" "$BIN_DIR/$name"
  rm -rf "$tmp"
}

# Skip the download when the pinned version is already installed. `$2` is the flag that makes the
# binary print its version, `$3` the version we want to see in that output.
already_at_version() {
  local name="$1" want="$2"
  [ -x "$BIN_DIR/$name" ] || return 1
  "$BIN_DIR/$name" --version 2>/dev/null | grep -qF "$want"
}

install_lune() {
  if already_at_version lune "$LUNE_VERSION"; then
    log "lune $LUNE_VERSION already installed"
    return
  fi
  log "installing lune $LUNE_VERSION"
  fetch_zip_binary lune \
    "https://github.com/lune-org/lune/releases/download/v${LUNE_VERSION}/lune-${LUNE_VERSION}-linux-x86_64.zip" \
    lune
}

install_luau_lsp() {
  if already_at_version luau-lsp "$LUAU_LSP_VERSION"; then
    log "luau-lsp $LUAU_LSP_VERSION already installed"
    return
  fi
  log "installing luau-lsp $LUAU_LSP_VERSION"
  fetch_zip_binary luau-lsp \
    "https://github.com/JohnnyMorganz/luau-lsp/releases/download/${LUAU_LSP_VERSION}/luau-lsp-linux-x86_64.zip" \
    luau-lsp
}

install_rojo() {
  if already_at_version rojo "$ROJO_VERSION"; then
    log "rojo $ROJO_VERSION already installed"
    return
  fi
  log "installing rojo $ROJO_VERSION"
  fetch_zip_binary rojo \
    "https://github.com/rojo-rbx/rojo/releases/download/v${ROJO_VERSION}/rojo-${ROJO_VERSION}-linux-x86_64.zip" \
    rojo
}

install_defs() {
  # The Roblox API surface the type checker needs to know `game:GetService` and friends. Re-fetched
  # only when absent — it is a generated artifact upstream regenerates on its own cadence, and a gate
  # that silently changes its own inputs on every run is a flaky gate.
  if [ -s "$SHARE_DIR/globalTypes.d.luau" ]; then
    log "Roblox type definitions already present"
    return
  fi
  log "fetching Roblox type definitions"
  curl -fsSL -o "$SHARE_DIR/globalTypes.d.luau" "$GLOBAL_TYPES_URL"
}

case "${1:-all}" in
  lune) install_lune ;;
  luau-lsp) install_luau_lsp ;;
  rojo) install_rojo ;;
  defs) install_defs ;;
  all)
    install_lune
    install_luau_lsp
    install_rojo
    install_defs
    ;;
  *)
    log "unknown component '$1' (expected: lune | luau-lsp | rojo | defs | all)"
    exit 2
    ;;
esac

log "ready — add to PATH: $BIN_DIR"
