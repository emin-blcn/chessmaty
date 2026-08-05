#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT/rust"

cargo xwin build --release --target x86_64-pc-windows-msvc

cd "$REPO_ROOT"

rm -f "$REPO_ROOT/godot/lib/librust_windows_x86_64_release.dll"
cp "$REPO_ROOT/rust/target/x86_64-pc-windows-msvc/release/rust.dll" "$REPO_ROOT/godot/lib/librust_windows_x86_64_release.dll"