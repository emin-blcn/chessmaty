#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT/rust"

cargo xwin build --target aarch64-pc-windows-msvc

cd "$REPO_ROOT"

rm -f "$REPO_ROOT/godot/lib/librust_windows_arm64_debug.dll"
cp "$REPO_ROOT/rust/target/aarch64-pc-windows-msvc/debug/rust.dll" "$REPO_ROOT/godot/lib/librust_windows_arm64_debug.dll"