#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT/rust"

cargo build --target x86_64-unknown-linux-gnu

cd "$REPO_ROOT"

rm -f "$REPO_ROOT/godot/lib/chessmaty_rust_linux_x86_64_debug.so"
cp "$REPO_ROOT/rust/target/x86_64-unknown-linux-gnu/debug/libchessmaty_rust.so" "$REPO_ROOT/godot/lib/chessmaty_rust_linux_x86_64_debug.so"